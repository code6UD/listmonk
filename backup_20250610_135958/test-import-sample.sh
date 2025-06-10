#!/bin/bash

# Script de test avec un échantillon de communes

echo "🧪 TEST D'IMPORT - ÉCHANTILLON"
echo "==============================="

# Configuration
API_USER="api"
API_TOKEN="RmAp4lu4hiMSE9GCV2KOSpjLWH0k7h1o"
API_URL="http://localhost:9000/api"
DB_CONTAINER="listmonk_mairies_db"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"

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

# Créer un échantillon de test
create_sample() {
    log_info "Création d'un échantillon de test (1000 communes)..."
    
    # Prendre l'en-tête + 1000 premières communes
    head -1 mairielist.csv > mairielist-sample-test.csv
    tail -n +2 mairielist.csv | head -1000 >> mairielist-sample-test.csv
    
    local sample_lines=$(wc -l < mairielist-sample-test.csv)
    log_success "Échantillon créé : $sample_lines lignes"
}

# Convertir l'échantillon
convert_sample() {
    log_info "Conversion de l'échantillon..."
    
    cat > convert_sample.py << 'EOF'
import csv
import json

def convert_sample():
    input_file = 'mairielist-sample-test.csv'
    output_file = 'mairielist-sample-converted.csv'
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.DictReader(infile)
        fieldnames = ['email', 'name', 'attribs']
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        
        count = 0
        for row in reader:
            email = row.get('email', '').strip()
            nom_commune = row.get('nom_commune', '').strip()
            
            if not email or '@' not in email:
                continue
            
            attribs = {
                'nom_commune': nom_commune,
                'departement_numero': row.get('departement_numero', '').strip(),
                'zipcode': row.get('zipcode', '').strip(),
                'population_commune': row.get('population_commune', '').strip(),
                'code_insee': row.get('code_insee', '').strip(),
                'city': row.get('city', '').strip(),
                'state': row.get('state', '').strip()
            }
            
            clean_attribs = {k: v for k, v in attribs.items() if v and v.lower() not in ['nan', 'null', '']}
            
            writer.writerow({
                'email': email,
                'name': nom_commune or email.split('@')[0],
                'attribs': json.dumps(clean_attribs, ensure_ascii=False)
            })
            
            count += 1
        
        print(f"Échantillon converti : {count} communes")

if __name__ == "__main__":
    convert_sample()
EOF

    python3 convert_sample.py
    
    if [ -f "mairielist-sample-converted.csv" ]; then
        local converted_lines=$(wc -l < mairielist-sample-converted.csv)
        log_success "Conversion terminée : $converted_lines lignes"
    else
        log_error "Échec de la conversion"
        exit 1
    fi
}

# Démarrer les services
start_services() {
    log_info "Démarrage des services Docker..."
    
    # Créer docker-compose.yml si nécessaire
    if [ ! -f "docker-compose.yml" ]; then
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  listmonk_mairies_db:
    image: postgres:13
    container_name: listmonk_mairies_db
    environment:
      POSTGRES_DB: listmonk_mairies
      POSTGRES_USER: listmonk_mairies
      POSTGRES_PASSWORD: listmonk_password
    volumes:
      - listmonk_mairies_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk_mairies"]
      interval: 10s
      timeout: 5s
      retries: 5

  listmonk_mairies:
    image: listmonk/listmonk:latest
    container_name: listmonk_mairies
    depends_on:
      listmonk_mairies_db:
        condition: service_healthy
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_db__host: "listmonk_mairies_db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk_mairies"
      LISTMONK_db__password: "listmonk_password"
      LISTMONK_db__database: "listmonk_mairies"
      LISTMONK_db__ssl_mode: "disable"
    ports:
      - "9000:9000"
    volumes:
      - ./config.toml:/listmonk/config.toml:ro
    command: ["./listmonk", "--config", "config.toml"]

volumes:
  listmonk_mairies_data:
EOF
    fi
    
    # Créer config.toml
    if [ ! -f "config.toml" ]; then
        cat > config.toml << 'EOF'
[app]
address = "0.0.0.0:9000"
admin_username = "api"
admin_password = "RmAp4lu4hiMSE9GCV2KOSpjLWH0k7h1o"

[db]
host = "listmonk_mairies_db"
port = 5432
user = "listmonk_mairies"
password = "listmonk_password"
database = "listmonk_mairies"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"
EOF
    fi
    
    # Démarrer
    docker compose up -d
    
    log_info "Attente du démarrage des services (45 secondes)..."
    sleep 45
    
    # Vérifier l'API
    local retries=0
    while [ $retries -lt 5 ]; do
        if curl -s -u "$API_USER:$API_TOKEN" "$API_URL/health" > /dev/null 2>&1; then
            log_success "API Listmonk accessible"
            return 0
        fi
        log_info "Attente de l'API... (tentative $((retries+1))/5)"
        sleep 10
        retries=$((retries+1))
    done
    
    log_error "API Listmonk non accessible"
    return 1
}

# Import de l'échantillon
import_sample() {
    log_info "Import de l'échantillon..."
    
    # Créer une liste
    local create_response=$(curl -s -u "$API_USER:$API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"name":"Test Communes","type":"public","optin":"single","tags":["test"]}' \
        "$API_URL/lists")
    
    local list_id=$(echo "$create_response" | jq -r '.data.id // empty' 2>/dev/null)
    
    if [ -z "$list_id" ] || [ "$list_id" = "null" ]; then
        log_error "Impossible de créer une liste"
        return 1
    fi
    
    log_success "Liste créée avec ID: $list_id"
    
    # Importer
    local import_response=$(curl -s -u "$API_USER:$API_TOKEN" \
        -F "file=@mairielist-sample-converted.csv" \
        -F "params={\"list_ids\":[$list_id],\"overwrite\":true,\"delim\":\",\",\"mode\":\"subscribe\"}" \
        "$API_URL/import/subscribers")
    
    log_info "Import lancé, attente..."
    sleep 20
    
    # Vérifier
    local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    log_success "Communes importées : $count"
    
    if [ "$count" -gt 500 ]; then
        log_success "Test d'import réussi !"
        return 0
    else
        log_warning "Import partiel"
        return 1
    fi
}

# Test des données géographiques
test_geo_data() {
    log_info "Test d'extraction des données géographiques..."
    
    cat > /tmp/test_geo.sql << 'EOF'
UPDATE subscribers SET
    department_code = CASE
        WHEN attribs->>'departement_numero' IS NOT NULL THEN 
            LPAD(attribs->>'departement_numero', 2, '0')
        WHEN attribs->>'zipcode' IS NOT NULL THEN 
            LPAD(substring(attribs->>'zipcode' from '^(\d{2})'), 2, '0')
        ELSE NULL
    END,
    population = CASE
        WHEN attribs->>'population_commune' IS NOT NULL 
             AND attribs->>'population_commune' ~ '^\d+$' THEN 
            (attribs->>'population_commune')::INTEGER
        ELSE NULL
    END
WHERE attribs IS NOT NULL;

SELECT 
    COUNT(*) as total,
    COUNT(department_code) as with_dept,
    COUNT(CASE WHEN population > 0 THEN 1 END) as with_pop
FROM subscribers;
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/test_geo.sql
    rm -f /tmp/test_geo.sql
    
    log_success "Test géographique terminé"
}

# Fonction principale
main() {
    echo ""
    log_info "Test d'import avec un échantillon de 1000 communes"
    echo ""
    
    create_sample
    convert_sample
    start_services
    
    if import_sample; then
        test_geo_data
        echo ""
        log_success "🎉 TEST RÉUSSI !"
        echo ""
        log_info "Le système fonctionne correctement."
        log_info "Vous pouvez maintenant lancer l'import complet :"
        log_info "./import-all-communes.sh"
        echo ""
        log_info "Interface web : http://localhost:9000"
        echo ""
    else
        log_error "Test échoué"
        exit 1
    fi
    
    # Nettoyer
    rm -f convert_sample.py mairielist-sample-test.csv mairielist-sample-converted.csv
}

# Exécuter
main "$@"