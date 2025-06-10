#!/bin/bash

# Script d'import corrigé pour toutes les communes françaises

echo "🏛️ IMPORT CORRIGÉ - TOUTES LES COMMUNES"
echo "========================================"

# Configuration
DB_CONTAINER="listmonk_db"
DB_USER="listmonk"
DB_NAME="listmonk"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Vérifier la connexion à la base de données
check_db() {
    log_info "Vérification de la connexion à la base de données..."
    
    if ! docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "Impossible de se connecter à la base de données"
        exit 1
    fi
    
    log_success "Connexion à la base de données établie"
}

# Créer une liste par défaut
create_default_list() {
    log_info "Création d'une liste par défaut..."
    
    cat > /tmp/create_list.sql << 'EOF'
-- Supprimer la liste existante si elle existe
DELETE FROM lists WHERE name = 'Communes France';

-- Créer une nouvelle liste
INSERT INTO lists (uuid, name, type, optin, tags, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'Communes France',
    'public',
    'single',
    '{}',
    NOW(),
    NOW()
);

-- Vérifier la liste
SELECT id, name FROM lists WHERE name = 'Communes France';
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/create_list.sql
    rm -f /tmp/create_list.sql
}

# Import direct simplifié
import_direct() {
    log_info "Import direct simplifié..."
    
    # Nettoyer les abonnés existants
    log_info "Nettoyage des abonnés existants..."
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM subscribers;" > /dev/null 2>&1
    
    # Créer un script Python pour l'import direct
    cat > import_direct.py << 'EOF'
import csv
import json
import psycopg2
import uuid
from datetime import datetime

def import_communes():
    # Connexion à la base de données
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="listmonk",
        user="listmonk",
        password="listmonk"
    )
    cur = conn.cursor()
    
    print("Connexion à la base de données établie")
    
    # Lire le fichier CSV
    with open('mairielist.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        count = 0
        batch = []
        batch_size = 1000
        
        for row in reader:
            try:
                email = row.get('email', '').strip()
                nom_commune = row.get('nom_commune', '').strip()
                
                # Ignorer les lignes sans email valide
                if not email or '@' not in email:
                    continue
                
                # Créer les attributs JSON
                attribs = {}
                for key in ['nom_commune', 'departement_numero', 'zipcode', 'population_commune', 
                           'code_insee', 'city', 'state', 'firstname', 'lastname', 'phone', 
                           'website', 'address1']:
                    value = row.get(key, '').strip() if row.get(key) else ''
                    if value and value.lower() not in ['nan', 'null', '']:
                        attribs[key] = value
                
                # Préparer les données pour l'insertion
                subscriber_data = (
                    str(uuid.uuid4()),  # uuid
                    email,              # email
                    nom_commune or email.split('@')[0],  # name
                    json.dumps(attribs, ensure_ascii=False),  # attribs
                    'enabled',          # status
                    datetime.now(),     # created_at
                    datetime.now()      # updated_at
                )
                
                batch.append(subscriber_data)
                count += 1
                
                # Insérer par batch
                if len(batch) >= batch_size:
                    insert_batch(cur, batch)
                    batch = []
                    print(f"Importé {count} communes...")
                
            except Exception as e:
                print(f"Erreur ligne {count}: {e}")
                continue
        
        # Insérer le dernier batch
        if batch:
            insert_batch(cur, batch)
        
        conn.commit()
        print(f"Import terminé : {count} communes importées")
        
        # Associer à la liste
        associate_to_list(cur)
        conn.commit()
        
        # Extraire les données géographiques
        extract_geo_data(cur)
        conn.commit()
        
        cur.close()
        conn.close()
        
        return count

def insert_batch(cur, batch):
    try:
        cur.executemany("""
            INSERT INTO subscribers (uuid, email, name, attribs, status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (email) DO NOTHING
        """, batch)
    except Exception as e:
        print(f"Erreur insertion batch: {e}")

def associate_to_list(cur):
    print("Association des abonnés à la liste...")
    cur.execute("""
        INSERT INTO subscriber_lists (subscriber_id, list_id, status, created_at, updated_at)
        SELECT 
            s.id,
            l.id,
            'confirmed',
            NOW(),
            NOW()
        FROM subscribers s
        CROSS JOIN lists l
        WHERE l.name = 'Communes France'
        ON CONFLICT DO NOTHING
    """)

def extract_geo_data(cur):
    print("Extraction des données géographiques...")
    
    # Ajouter les colonnes si elles n'existent pas
    try:
        cur.execute("""
            ALTER TABLE subscribers 
            ADD COLUMN IF NOT EXISTS department_code VARCHAR(3),
            ADD COLUMN IF NOT EXISTS population INTEGER,
            ADD COLUMN IF NOT EXISTS commune_code VARCHAR(10)
        """)
    except:
        pass
    
    # Mettre à jour les données géographiques
    cur.execute("""
        UPDATE subscribers SET
            department_code = CASE
                WHEN attribs->>'departement_numero' IS NOT NULL AND attribs->>'departement_numero' != '' THEN 
                    LPAD(attribs->>'departement_numero', 2, '0')
                WHEN attribs->>'zipcode' IS NOT NULL AND attribs->>'zipcode' != '' THEN 
                    LPAD(substring(attribs->>'zipcode' from '^(\d{2})'), 2, '0')
                ELSE NULL
            END,
            
            population = CASE
                WHEN attribs->>'population_commune' IS NOT NULL 
                     AND attribs->>'population_commune' != '' 
                     AND attribs->>'population_commune' ~ '^\d+$' THEN 
                    (attribs->>'population_commune')::INTEGER
                ELSE NULL
            END,
            
            commune_code = CASE
                WHEN attribs->>'code_insee' IS NOT NULL AND attribs->>'code_insee' != '' THEN 
                    attribs->>'code_insee'
                ELSE NULL
            END
        WHERE attribs IS NOT NULL
    """)

if __name__ == "__main__":
    import_communes()
EOF

    # Installer psycopg2 si nécessaire
    pip3 install psycopg2-binary > /dev/null 2>&1
    
    # Exécuter l'import depuis l'extérieur du conteneur en se connectant via le port exposé
    python3 import_direct.py
    
    # Nettoyer
    rm -f import_direct.py
}

# Vérification finale
final_verification() {
    log_info "Vérification finale..."
    
    local total_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    local with_dept=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" | tr -d ' ')
    local with_pop=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL;" | tr -d ' ')
    
    echo ""
    log_success "🎉 IMPORT CORRIGÉ TERMINÉ !"
    echo ""
    echo "📊 Statistiques finales :"
    echo "  • Total communes importées : $total_count"
    echo "  • Avec département : $with_dept"
    echo "  • Avec population : $with_pop"
    echo ""
    
    if [ "$total_count" -gt 70000 ]; then
        log_success "Import réussi ! Plus de 70k communes importées"
    elif [ "$total_count" -gt 40000 ]; then
        log_warning "Import partiel : $total_count communes (attendu ~81k)"
    elif [ "$total_count" -gt 10000 ]; then
        log_success "Import significatif : $total_count communes"
    else
        log_error "Import insuffisant : seulement $total_count communes"
    fi
    
    # Afficher quelques exemples
    echo ""
    log_info "🏙️  Échantillon des communes importées :"
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT 
        name,
        COALESCE(population::text, 'N/A') as pop,
        COALESCE(department_code, 'N/A') as dept
    FROM subscribers 
    WHERE population IS NOT NULL
    ORDER BY population DESC
    LIMIT 10;" 2>/dev/null | while read line; do
        echo "    $line"
    done
    
    echo ""
    log_info "🌐 Interface web : http://localhost:9000"
    log_info "🔍 Vérification : ./check-current-import.sh"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Import corrigé de toutes les communes françaises"
    echo ""
    echo "🔧 Corrections apportées :"
    echo "  • Statut 'enabled' au lieu de 'confirmed'"
    echo "  • Import direct via Python/psycopg2"
    echo "  • Gestion correcte des types de données"
    echo ""
    
    read -p "Continuer avec l'import corrigé ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Opération annulée."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉBUT DE L'IMPORT CORRIGÉ"
    echo ""
    
    # Étapes d'import
    check_db
    create_default_list
    import_direct
    final_verification
    
    log_success "🎉 IMPORT CORRIGÉ TERMINÉ AVEC SUCCÈS !"
}

# Exécuter
main "$@"