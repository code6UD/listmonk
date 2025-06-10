#!/bin/bash

# Script de déploiement final pour les mairies françaises avec docker-compose.mairies.yml

echo "🏛️ DÉPLOIEMENT FINAL - MAIRIES FRANÇAISES"
echo "=========================================="

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

# Configuration basée sur docker-compose.mairies.yml
CONTAINER_APP="listmonk_mairies_app"
CONTAINER_DB="listmonk_mairies_db"
CONTAINER_REDIS="listmonk_mairies_redis"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
DB_PASSWORD="listmonk_mairies_2024"
COMPOSE_FILE="docker-compose.mairies.yml"

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Fichier $COMPOSE_FILE non trouvé"
        exit 1
    fi
    
    if [ ! -f "mairielist.csv" ]; then
        log_error "Fichier mairielist.csv non trouvé"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Créer les répertoires nécessaires
create_directories() {
    log_info "Création des répertoires nécessaires..."
    
    mkdir -p uploads data imports scripts
    
    log_success "Répertoires créés"
}

# Créer le fichier d'initialisation de la base de données
create_init_sql() {
    log_info "Création du script d'initialisation de la base de données..."
    
    cat > scripts/init-mairies.sql << 'EOF'
-- Script d'initialisation pour les mairies françaises
-- Création des extensions nécessaires

-- Extension PostGIS pour les données géographiques
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Extension pour les UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extension pour les statistiques
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Création d'un index spatial si nécessaire (sera utilisé plus tard)
-- CREATE INDEX IF NOT EXISTS idx_subscribers_location ON subscribers USING GIST(location);

-- Configuration pour les données françaises
SET timezone = 'Europe/Paris';

-- Commentaire pour traçabilité
COMMENT ON DATABASE listmonk_mairies IS 'Base de données Listmonk pour les mairies françaises';
EOF

    log_success "Script d'initialisation créé"
}

# Créer le fichier .env
create_env_file() {
    log_info "Création du fichier d'environnement..."
    
    cat > .env << 'EOF'
# Configuration pour les mairies françaises
LISTMONK_ADMIN_USER=admin
LISTMONK_ADMIN_PASSWORD=listmonk123

# Configuration de la base de données
POSTGRES_USER=listmonk_mairies
POSTGRES_PASSWORD=listmonk_mairies_2024
POSTGRES_DB=listmonk_mairies

# Timezone
TZ=Europe/Paris
EOF

    log_success "Fichier .env créé"
}

# Arrêter les anciens conteneurs
stop_old_containers() {
    log_info "Arrêt des anciens conteneurs..."
    
    # Arrêter avec le fichier de composition spécifique
    docker-compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
    
    # Arrêter tous les conteneurs listmonk existants
    docker ps -a | grep listmonk | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
    docker ps -a | grep listmonk | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true
    
    log_success "Anciens conteneurs arrêtés"
}

# Construire et démarrer les services
start_services() {
    log_info "Construction et démarrage des services..."
    
    # Construire l'image personnalisée
    log_info "Construction de l'image Listmonk personnalisée..."
    docker-compose -f "$COMPOSE_FILE" build app
    
    # Démarrer tous les services
    log_info "Démarrage des services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Attendre que les services soient prêts
    log_info "Attente du démarrage des services..."
    sleep 60
    
    # Vérifier que les services sont en cours d'exécution
    if docker ps | grep -q "$CONTAINER_APP" && docker ps | grep -q "$CONTAINER_DB"; then
        log_success "Services démarrés avec succès"
    else
        log_error "Échec du démarrage des services"
        log_info "Logs des conteneurs :"
        docker-compose -f "$COMPOSE_FILE" logs --tail=20
        exit 1
    fi
}

# Attendre que Listmonk soit prêt
wait_for_listmonk() {
    log_info "Attente que Listmonk soit prêt..."
    
    local max_attempts=60
    for attempt in $(seq 1 $max_attempts); do
        if curl -s http://localhost:9000 > /dev/null 2>&1; then
            log_success "Listmonk accessible sur http://localhost:9000"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Listmonk non accessible après $max_attempts tentatives"
            log_info "Logs de l'application :"
            docker logs "$CONTAINER_APP" --tail=20
            exit 1
        fi
        
        log_info "Attente de Listmonk... ($attempt/$max_attempts)"
        sleep 5
    done
}

# Importer les communes
import_communes() {
    log_info "Import des communes françaises..."
    
    # Créer un script Python pour l'import
    cat > import_communes.py << 'EOF'
import csv
import json
import psycopg2
import uuid
from datetime import datetime
import sys

def import_communes():
    try:
        # Connexion à la base de données via le port exposé
        conn = psycopg2.connect(
            host="localhost",
            port=5433,  # Port exposé dans docker-compose.mairies.yml
            database="listmonk_mairies",
            user="listmonk_mairies",
            password="listmonk_mairies_2024"
        )
        cur = conn.cursor()
        
        print("Connexion à la base de données établie")
        
        # Créer une liste par défaut
        cur.execute("""
            INSERT INTO lists (uuid, name, type, optin, tags, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """, (
            str(uuid.uuid4()),
            'Communes France',
            'public',
            'single',
            '{}',
            datetime.now(),
            datetime.now()
        ))
        
        # Lire le fichier CSV
        with open('mairielist.csv', 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            count = 0
            batch = []
            batch_size = 1000
            unique_emails = set()
            
            for row in reader:
                try:
                    email = row.get('email', '').strip()
                    nom_commune = row.get('nom_commune', '').strip()
                    
                    # Ignorer les lignes sans email valide ou les doublons
                    if not email or '@' not in email or email.lower() in unique_emails:
                        continue
                    
                    unique_emails.add(email.lower())
                    
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
            
    except Exception as e:
        print(f"Erreur d'import : {e}")
        return 0

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
                    LPAD(substring(attribs->>'zipcode' from '^(\\d{2})'), 2, '0')
                ELSE NULL
            END,
            
            population = CASE
                WHEN attribs->>'population_commune' IS NOT NULL 
                     AND attribs->>'population_commune' != '' 
                     AND attribs->>'population_commune' ~ '^\\d+$' THEN 
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
    
    # Exécuter l'import
    python3 import_communes.py
    
    # Nettoyer
    rm -f import_communes.py
    
    log_success "Import des communes terminé"
}

# Créer l'interface de ciblage géographique
setup_geo_interface() {
    log_info "Configuration de l'interface de ciblage géographique..."
    
    # Créer le répertoire static s'il n'existe pas
    mkdir -p static/public
    
    # Copier les fichiers d'interface s'ils existent
    if [ -f "geo-targeting.js" ]; then
        cp geo-targeting.js static/public/
        log_success "Interface de ciblage copiée"
    fi
    
    if [ -f "bookmarklet.html" ]; then
        log_success "Bookmarklet disponible"
    fi
    
    # Redémarrer le conteneur app pour prendre en compte les nouveaux fichiers
    log_info "Redémarrage du conteneur application..."
    docker-compose -f "$COMPOSE_FILE" restart app
    
    sleep 10
}

# Vérification finale
final_verification() {
    log_info "Vérification finale du système..."
    
    # Vérifier l'accès web
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Interface web accessible sur http://localhost:9000"
    else
        log_error "Interface web non accessible"
    fi
    
    # Vérifier les données
    local communes_count=$(docker exec "$CONTAINER_DB" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    if [ -n "$communes_count" ] && [ "$communes_count" -gt 0 ]; then
        log_success "Communes importées : $communes_count"
    else
        log_error "Aucune commune trouvée"
    fi
    
    # Vérifier les données géographiques
    local with_dept=$(docker exec "$CONTAINER_DB" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
    if [ -n "$with_dept" ] && [ "$with_dept" -gt 0 ]; then
        log_success "Communes avec département : $with_dept"
    else
        log_warning "Données de département manquantes"
    fi
    
    # Vérifier Redis
    if docker exec "$CONTAINER_REDIS" redis-cli ping > /dev/null 2>&1; then
        log_success "Redis opérationnel"
    else
        log_warning "Redis non accessible"
    fi
}

# Afficher les instructions finales
show_final_instructions() {
    echo ""
    log_success "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"
    echo ""
    echo "📊 Système opérationnel :"
    echo "  • Interface web : http://localhost:9000"
    echo "  • Interface alternative : http://localhost:12000"
    echo "  • Utilisateur : admin"
    echo "  • Mot de passe : listmonk123"
    echo ""
    echo "🗄️ Outils de gestion :"
    echo "  • Adminer (DB) : http://localhost:8082 (profil dev)"
    echo "  • Redis Commander : http://localhost:8083 (profil dev)"
    echo ""
    echo "🎯 Pour activer le ciblage géographique :"
    echo "  1. Ouvrez bookmarklet.html dans votre navigateur"
    echo "  2. Glissez le lien dans vos favoris"
    echo "  3. Allez sur http://localhost:9000"
    echo "  4. Cliquez sur le favori pour activer l'interface"
    echo ""
    echo "🛠️ Commandes utiles :"
    echo "  • Redémarrer : docker-compose -f $COMPOSE_FILE restart"
    echo "  • Arrêter : docker-compose -f $COMPOSE_FILE down"
    echo "  • Logs : docker-compose -f $COMPOSE_FILE logs -f"
    echo "  • Profil dev : docker-compose -f $COMPOSE_FILE --profile dev up -d"
    echo ""
    echo "📊 Statistiques :"
    local communes_count=$(docker exec "$CONTAINER_DB" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    local with_dept=$(docker exec "$CONTAINER_DB" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
    echo "  • Total communes : ${communes_count:-0}"
    echo "  • Avec département : ${with_dept:-0}"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Déploiement du système de ciblage géographique pour mairies françaises"
    log_info "Utilisation du fichier : $COMPOSE_FILE"
    echo ""
    
    read -p "Continuer avec le déploiement ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Déploiement annulé."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉBUT DU DÉPLOIEMENT"
    echo ""
    
    check_prerequisites
    create_directories
    create_init_sql
    create_env_file
    stop_old_containers
    start_services
    wait_for_listmonk
    import_communes
    setup_geo_interface
    final_verification
    show_final_instructions
}

# Exécuter
main "$@"