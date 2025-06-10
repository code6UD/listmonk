#!/bin/bash

# Script de déploiement pour le nouveau dépôt avec intégration des communes françaises

echo "🚀 DÉPLOIEMENT NOUVEAU SYSTÈME COMMUNES FRANÇAISES"
echo "=================================================="

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

# Configuration
CONTAINER_APP="listmonk_app"
CONTAINER_DB="listmonk_db"
DB_USER="listmonk"
DB_NAME="listmonk"
DB_PASSWORD="listmonk"

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
    
    if [ ! -f "mairielist.csv" ]; then
        log_error "Fichier mairielist.csv non trouvé"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Arrêter les anciens conteneurs
stop_old_containers() {
    log_info "Arrêt des anciens conteneurs..."
    
    # Arrêter tous les conteneurs listmonk existants
    docker ps -a | grep listmonk | awk '{print $1}' | xargs -r docker stop
    docker ps -a | grep listmonk | awk '{print $1}' | xargs -r docker rm
    
    log_success "Anciens conteneurs arrêtés"
}

# Créer la configuration Docker Compose
create_docker_compose() {
    log_info "Création de la configuration Docker Compose..."
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  listmonk_db:
    image: postgres:17-alpine
    container_name: listmonk_db
    environment:
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk
      POSTGRES_DB: listmonk
    volumes:
      - listmonk_db_data:/var/lib/postgresql/data
    networks:
      - listmonk
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  listmonk_app:
    image: listmonk/listmonk:latest
    container_name: listmonk_app
    depends_on:
      listmonk_db:
        condition: service_healthy
    ports:
      - "9000:9000"
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_db__host: "listmonk_db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk"
      LISTMONK_db__password: "listmonk"
      LISTMONK_db__database: "listmonk"
      LISTMONK_db__ssl_mode: "disable"
    volumes:
      - ./config.toml:/listmonk/config.toml:ro
      - ./static:/listmonk/static
    networks:
      - listmonk
    restart: unless-stopped

volumes:
  listmonk_db_data:

networks:
  listmonk:
    driver: bridge
EOF

    log_success "Configuration Docker Compose créée"
}

# Créer la configuration Listmonk
create_config() {
    log_info "Création de la configuration Listmonk..."
    
    cat > config.toml << 'EOF'
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "listmonk123"

[db]
host = "listmonk_db"
port = 5432
user = "listmonk"
password = "listmonk"
database = "listmonk"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"

[privacy]
individual_tracking = false
unsubscribe_header = true
allow_blocklist = true
allow_export = true
allow_wipe = true
exportable = ["profile", "subscriptions", "campaign_views", "link_clicks"]

[security]
enable_captcha = false

[upload]
provider = "filesystem"
filesystem.upload_path = "./uploads"
filesystem.upload_uri = "/uploads"

[bounce]
enabled = false

[smtp]
[[smtp.host]]
enabled = true
host = "localhost"
port = 1025
auth_protocol = "none"
username = ""
password = ""
hello_hostname = ""
max_conns = 10
idle_timeout = "15s"
wait_timeout = "5s"
max_msg_retries = 2
tls_enabled = false
tls_skip_verify = false
email_headers = []
EOF

    log_success "Configuration Listmonk créée"
}

# Démarrer les services
start_services() {
    log_info "Démarrage des services Docker..."
    
    docker-compose up -d
    
    # Attendre que les services soient prêts
    log_info "Attente du démarrage des services..."
    sleep 30
    
    # Vérifier que les services sont en cours d'exécution
    if docker ps | grep -q listmonk_app && docker ps | grep -q listmonk_db; then
        log_success "Services démarrés avec succès"
    else
        log_error "Échec du démarrage des services"
        docker-compose logs
        exit 1
    fi
}

# Installer Listmonk
install_listmonk() {
    log_info "Installation de Listmonk..."
    
    # Attendre que la base de données soit prête
    local max_attempts=30
    for attempt in $(seq 1 $max_attempts); do
        if docker exec listmonk_db pg_isready -U listmonk -d listmonk > /dev/null 2>&1; then
            log_success "Base de données prête"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Base de données non accessible après $max_attempts tentatives"
            exit 1
        fi
        
        log_info "Attente de la base de données... ($attempt/$max_attempts)"
        sleep 2
    done
    
    # Installer Listmonk
    log_info "Exécution de l'installation Listmonk..."
    docker exec listmonk_app ./listmonk --install --yes
    
    log_success "Listmonk installé"
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
        # Connexion à la base de données via le conteneur
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="listmonk",
            user="listmonk",
            password="listmonk"
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
create_geo_interface() {
    log_info "Création de l'interface de ciblage géographique..."
    
    # Créer le répertoire static s'il n'existe pas
    mkdir -p static/public
    
    # Copier le script de ciblage géographique
    if [ -f "geo-targeting.js" ]; then
        cp geo-targeting.js static/public/
        log_success "Interface de ciblage copiée"
    else
        log_warning "Fichier geo-targeting.js non trouvé"
    fi
    
    # Créer le bookmarklet
    if [ -f "bookmarklet.html" ]; then
        log_success "Bookmarklet disponible"
    else
        log_warning "Fichier bookmarklet.html non trouvé"
    fi
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
    local communes_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    if [ -n "$communes_count" ] && [ "$communes_count" -gt 0 ]; then
        log_success "Communes importées : $communes_count"
    else
        log_error "Aucune commune trouvée"
    fi
    
    # Vérifier les données géographiques
    local with_dept=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
    if [ -n "$with_dept" ] && [ "$with_dept" -gt 0 ]; then
        log_success "Communes avec département : $with_dept"
    else
        log_warning "Données de département manquantes"
    fi
}

# Afficher les instructions finales
show_final_instructions() {
    echo ""
    log_success "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"
    echo ""
    echo "📊 Système opérationnel :"
    echo "  • Interface web : http://localhost:9000"
    echo "  • Utilisateur : admin"
    echo "  • Mot de passe : listmonk123"
    echo ""
    echo "🎯 Pour activer le ciblage géographique :"
    echo "  1. Ouvrez bookmarklet.html dans votre navigateur"
    echo "  2. Glissez le lien dans vos favoris"
    echo "  3. Allez sur http://localhost:9000"
    echo "  4. Cliquez sur le favori pour activer l'interface"
    echo ""
    echo "🛠️ Commandes utiles :"
    echo "  • Redémarrer : docker-compose restart"
    echo "  • Arrêter : docker-compose down"
    echo "  • Logs : docker-compose logs -f"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Déploiement du système de ciblage géographique pour communes françaises"
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
    stop_old_containers
    create_docker_compose
    create_config
    start_services
    install_listmonk
    import_communes
    create_geo_interface
    final_verification
    show_final_instructions
}

# Exécuter
main "$@"