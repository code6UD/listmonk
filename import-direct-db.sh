#!/bin/bash

# Script d'import direct en base de données (sans API)

echo "🏛️ IMPORT DIRECT EN BASE DE DONNÉES"
echo "===================================="

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

# Convertir le fichier CSV complet
convert_csv() {
    log_info "Conversion du fichier CSV complet..."
    
    cat > convert_full.py << 'EOF'
import csv
import json
import sys

def convert_csv():
    input_file = 'mairielist.csv'
    output_file = 'communes_full.csv'
    
    print(f"Conversion de {input_file} vers {output_file}")
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.DictReader(infile)
        
        # En-têtes pour l'import direct
        fieldnames = ['email', 'name', 'status', 'attribs']
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        
        count = 0
        for row in reader:
            try:
                email = row.get('email', '').strip()
                nom_commune = row.get('nom_commune', '').strip()
                
                # Ignorer les lignes sans email valide
                if not email or '@' not in email:
                    continue
                
                # Créer les attributs JSON
                attribs = {
                    'nom_commune': nom_commune,
                    'departement_numero': row.get('departement_numero', '').strip(),
                    'zipcode': row.get('zipcode', '').strip(),
                    'population_commune': row.get('population_commune', '').strip(),
                    'code_insee': row.get('code_insee', '').strip(),
                    'city': row.get('city', '').strip(),
                    'state': row.get('state', '').strip(),
                    'firstname': row.get('firstname', '').strip(),
                    'lastname': row.get('lastname', '').strip(),
                    'phone': row.get('phone', '').strip(),
                    'website': row.get('website', '').strip(),
                    'address1': row.get('address1', '').strip()
                }
                
                # Nettoyer les attributs
                clean_attribs = {}
                for key, value in attribs.items():
                    if value and value.lower() not in ['nan', 'null', '']:
                        clean_attribs[key] = value
                
                # Écrire la ligne
                writer.writerow({
                    'email': email,
                    'name': nom_commune or email.split('@')[0],
                    'status': 'confirmed',
                    'attribs': json.dumps(clean_attribs, ensure_ascii=False)
                })
                
                count += 1
                if count % 10000 == 0:
                    print(f"Traité {count} communes...")
                    
            except Exception as e:
                print(f"Erreur ligne {count}: {e}")
                continue
        
        print(f"Conversion terminée : {count} communes converties")
        return count

if __name__ == "__main__":
    convert_csv()
EOF

    python3 convert_full.py
    
    if [ -f "communes_full.csv" ]; then
        local converted_lines=$(wc -l < communes_full.csv)
        log_success "Conversion terminée : $converted_lines lignes"
    else
        log_error "Échec de la conversion"
        exit 1
    fi
}

# Créer une liste par défaut
create_default_list() {
    log_info "Création d'une liste par défaut..."
    
    cat > /tmp/create_list.sql << 'EOF'
-- Créer une liste par défaut si elle n'existe pas
INSERT INTO lists (uuid, name, type, optin, tags, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'Communes France',
    'public',
    'single',
    '["communes", "france"]',
    NOW(),
    NOW()
) ON CONFLICT DO NOTHING;

-- Vérifier la liste
SELECT id, name FROM lists WHERE name = 'Communes France';
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/create_list.sql
    rm -f /tmp/create_list.sql
}

# Import direct en base de données par batch
import_by_batch() {
    log_info "Import par batch en base de données..."
    
    local csv_file="communes_full.csv"
    local total_lines=$(wc -l < "$csv_file")
    local total_communes=$((total_lines - 1))
    local batch_size=5000
    local batches=$(((total_communes + batch_size - 1) / batch_size))
    
    log_info "Total communes à importer : $total_communes"
    log_info "Taille des batches : $batch_size"
    log_info "Nombre de batches : $batches"
    
    # Nettoyer les abonnés existants
    log_info "Nettoyage des abonnés existants..."
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM subscribers;" > /dev/null 2>&1
    
    # Traiter chaque batch
    for ((batch=1; batch<=batches; batch++)); do
        local start_line=$(((batch - 1) * batch_size + 2)) # +2 pour ignorer l'en-tête
        local end_line=$((batch * batch_size + 1))
        
        log_info "Traitement du batch $batch/$batches (lignes $start_line à $end_line)..."
        
        # Créer un fichier temporaire pour ce batch
        local batch_file="batch_${batch}.csv"
        
        # Copier l'en-tête
        head -1 "$csv_file" > "$batch_file"
        
        # Ajouter les lignes du batch
        sed -n "${start_line},${end_line}p" "$csv_file" >> "$batch_file"
        
        # Créer un script SQL pour ce batch
        cat > /tmp/import_batch.sql << 'EOF'
-- Import temporaire dans une table
CREATE TEMP TABLE temp_import (
    email TEXT,
    name TEXT,
    status TEXT,
    attribs JSONB
);

-- Copier les données depuis le CSV
\copy temp_import FROM '/tmp/batch_current.csv' WITH CSV HEADER;

-- Insérer dans la table subscribers
INSERT INTO subscribers (uuid, email, name, status, attribs, created_at, updated_at)
SELECT 
    gen_random_uuid(),
    email,
    name,
    status::subscriber_status,
    attribs,
    NOW(),
    NOW()
FROM temp_import
WHERE email IS NOT NULL AND email != ''
ON CONFLICT (email) DO NOTHING;

-- Nettoyer
DROP TABLE temp_import;
EOF

        # Copier le fichier batch dans le conteneur
        docker cp "$batch_file" "$DB_CONTAINER:/tmp/batch_current.csv"
        
        # Exécuter l'import
        docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/import_batch.sql > /dev/null 2>&1
        
        # Nettoyer
        rm -f "$batch_file"
        docker exec "$DB_CONTAINER" rm -f /tmp/batch_current.csv
        
        # Vérifier le progrès
        local current_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
        log_info "Communes importées : $current_count"
        
        # Pause entre les batches
        sleep 1
    done
    
    rm -f /tmp/import_batch.sql
}

# Associer les abonnés à la liste
associate_to_list() {
    log_info "Association des abonnés à la liste..."
    
    cat > /tmp/associate_list.sql << 'EOF'
-- Associer tous les abonnés à la liste par défaut
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
ON CONFLICT DO NOTHING;

-- Statistiques
SELECT 
    COUNT(*) as total_subscribers,
    (SELECT COUNT(*) FROM subscriber_lists) as total_associations
FROM subscribers;
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/associate_list.sql
    rm -f /tmp/associate_list.sql
}

# Extraction des données géographiques
extract_geo_data() {
    log_info "Extraction des données géographiques..."
    
    cat > /tmp/extract_geo.sql << 'EOF'
-- Ajouter les colonnes géographiques si elles n'existent pas
ALTER TABLE subscribers 
ADD COLUMN IF NOT EXISTS department_code VARCHAR(3),
ADD COLUMN IF NOT EXISTS population INTEGER,
ADD COLUMN IF NOT EXISTS commune_code VARCHAR(10);

-- Mise à jour des données géographiques
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
WHERE attribs IS NOT NULL;

-- Statistiques finales
SELECT 
    'Total abonnés' as metric,
    COUNT(*) as count
FROM subscribers
UNION ALL
SELECT 
    'Avec département' as metric,
    COUNT(*) as count
FROM subscribers 
WHERE department_code IS NOT NULL
UNION ALL
SELECT 
    'Avec population' as metric,
    COUNT(*) as count
FROM subscribers 
WHERE population IS NOT NULL AND population > 0
UNION ALL
SELECT 
    'Avec code INSEE' as metric,
    COUNT(*) as count
FROM subscribers 
WHERE commune_code IS NOT NULL;
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/extract_geo.sql
    rm -f /tmp/extract_geo.sql
}

# Vérification finale
final_verification() {
    log_info "Vérification finale..."
    
    local total_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    local with_dept=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" | tr -d ' ')
    local with_pop=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL;" | tr -d ' ')
    
    echo ""
    log_success "🎉 IMPORT DIRECT TERMINÉ !"
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
    else
        log_error "Import insuffisant : seulement $total_count communes"
    fi
    
    echo ""
    log_info "🌐 Interface web : http://localhost:9000"
    log_info "🔍 Vérification : ./check-current-import.sh"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Import direct de toutes les communes françaises en base de données"
    echo ""
    echo "⚠️  ATTENTION :"
    echo "  • L'import peut prendre 20-40 minutes"
    echo "  • Bypass de l'API Listmonk (import direct en DB)"
    echo "  • Toutes les données existantes seront remplacées"
    echo ""
    
    read -p "Continuer avec l'import direct ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Opération annulée."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉBUT DE L'IMPORT DIRECT"
    echo ""
    
    # Étapes d'import
    check_db
    convert_csv
    create_default_list
    import_by_batch
    associate_to_list
    extract_geo_data
    final_verification
    
    # Nettoyer les fichiers temporaires
    rm -f convert_full.py communes_full.csv
    
    log_success "🎉 IMPORT DIRECT TERMINÉ AVEC SUCCÈS !"
}

# Exécuter
main "$@"