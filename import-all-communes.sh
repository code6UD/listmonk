#!/bin/bash

# Script d'import complet de toutes les communes françaises (81k+)

echo "🏛️ IMPORT COMPLET DES COMMUNES FRANÇAISES"
echo "========================================="

# Configuration
API_USER="api"
API_TOKEN="RmAp4lu4hiMSE9GCV2KOSpjLWH0k7h1o"
API_URL="http://localhost:9000/api"
DB_CONTAINER="listmonk_mairies_db"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
BATCH_SIZE=1000

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

# Installer les dépendances nécessaires
install_dependencies() {
    log_info "Installation des dépendances..."
    
    if ! command -v jq &> /dev/null; then
        log_info "Installation de jq..."
        apt-get update && apt-get install -y jq
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_info "Installation de Python3..."
        apt-get install -y python3 python3-pip
    fi
    
    log_success "Dépendances installées"
}

# Vérifier le fichier source
check_source_file() {
    log_info "Vérification du fichier source..."
    
    if [ ! -f "mairielist.csv" ]; then
        log_error "Fichier mairielist.csv non trouvé"
        exit 1
    fi
    
    local total_lines=$(wc -l < mairielist.csv)
    log_info "Fichier source trouvé : $total_lines lignes"
    
    # Vérifier l'en-tête
    local header=$(head -1 mairielist.csv)
    if [[ "$header" == *"email"* ]] && [[ "$header" == *"nom_commune"* ]]; then
        log_success "Format du fichier source validé"
    else
        log_error "Format du fichier source invalide"
        exit 1
    fi
}

# Convertir le fichier CSV complet pour Listmonk
convert_full_csv() {
    log_info "Conversion du fichier CSV complet..."
    
    # Créer un script Python pour la conversion
    cat > convert_csv.py << 'EOF'
import csv
import json
import sys

def convert_csv():
    input_file = 'mairielist.csv'
    output_file = 'mairielist-full-listmonk.csv'
    
    print(f"Conversion de {input_file} vers {output_file}")
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.DictReader(infile)
        
        # En-têtes pour Listmonk
        fieldnames = ['email', 'name', 'attribs']
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        
        count = 0
        for row in reader:
            try:
                # Extraire les données importantes
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
                
                # Nettoyer les attributs (supprimer les valeurs vides ou 'nan')
                clean_attribs = {}
                for key, value in attribs.items():
                    if value and value.lower() not in ['nan', 'null', '']:
                        clean_attribs[key] = value
                
                # Écrire la ligne
                writer.writerow({
                    'email': email,
                    'name': nom_commune or email.split('@')[0],
                    'attribs': json.dumps(clean_attribs, ensure_ascii=False)
                })
                
                count += 1
                if count % 5000 == 0:
                    print(f"Traité {count} communes...")
                    
            except Exception as e:
                print(f"Erreur ligne {count}: {e}")
                continue
        
        print(f"Conversion terminée : {count} communes converties")
        return count

if __name__ == "__main__":
    convert_csv()
EOF

    # Exécuter la conversion
    python3 convert_csv.py
    
    if [ -f "mairielist-full-listmonk.csv" ]; then
        local converted_lines=$(wc -l < mairielist-full-listmonk.csv)
        log_success "Conversion terminée : $converted_lines lignes"
    else
        log_error "Échec de la conversion"
        exit 1
    fi
}

# Démarrer les services Docker
start_services() {
    log_info "Démarrage des services Docker..."
    
    # Vérifier si docker-compose.yml existe
    if [ ! -f "docker-compose.yml" ]; then
        log_warning "docker-compose.yml non trouvé, création..."
        create_docker_compose
    fi
    
    # Démarrer les services
    docker-compose up -d
    
    # Attendre que les services soient prêts
    log_info "Attente du démarrage des services (30 secondes)..."
    sleep 30
    
    # Vérifier que l'API est accessible
    local retries=0
    while [ $retries -lt 10 ]; do
        if curl -s -u "$API_USER:$API_TOKEN" "$API_URL/health" > /dev/null 2>&1; then
            log_success "API Listmonk accessible"
            return 0
        fi
        log_info "Attente de l'API... (tentative $((retries+1))/10)"
        sleep 10
        retries=$((retries+1))
    done
    
    log_error "API Listmonk non accessible après 10 tentatives"
    return 1
}

# Créer docker-compose.yml si nécessaire
create_docker_compose() {
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
    
    # Créer config.toml si nécessaire
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
}

# Import par batch pour éviter les timeouts
import_by_batch() {
    log_info "Import par batch de $BATCH_SIZE communes..."
    
    local csv_file="mairielist-full-listmonk.csv"
    local total_lines=$(wc -l < "$csv_file")
    local total_communes=$((total_lines - 1)) # Exclure l'en-tête
    local batches=$(((total_communes + BATCH_SIZE - 1) / BATCH_SIZE))
    
    log_info "Total communes à importer : $total_communes"
    log_info "Nombre de batches : $batches"
    
    # Obtenir ou créer une liste
    local list_id=$(get_or_create_list)
    if [ -z "$list_id" ]; then
        log_error "Impossible de créer/obtenir une liste"
        return 1
    fi
    
    # Nettoyer les abonnés existants
    log_info "Nettoyage des abonnés existants..."
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM subscribers;" > /dev/null 2>&1
    
    # Traiter chaque batch
    for ((batch=1; batch<=batches; batch++)); do
        local start_line=$(((batch - 1) * BATCH_SIZE + 2)) # +2 pour ignorer l'en-tête
        local end_line=$((batch * BATCH_SIZE + 1))
        
        log_info "Traitement du batch $batch/$batches (lignes $start_line à $end_line)..."
        
        # Créer un fichier temporaire pour ce batch
        local batch_file="batch_${batch}.csv"
        
        # Copier l'en-tête
        head -1 "$csv_file" > "$batch_file"
        
        # Ajouter les lignes du batch
        sed -n "${start_line},${end_line}p" "$csv_file" >> "$batch_file"
        
        # Importer ce batch
        local import_response=$(curl -s -u "$API_USER:$API_TOKEN" \
            -F "file=@$batch_file" \
            -F "params={\"list_ids\":[$list_id],\"overwrite\":false,\"delim\":\",\",\"mode\":\"subscribe\"}" \
            "$API_URL/import/subscribers")
        
        log_info "Batch $batch importé, attente..."
        sleep 5
        
        # Nettoyer le fichier temporaire
        rm -f "$batch_file"
        
        # Vérifier le progrès
        local current_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
        log_info "Communes importées jusqu'à présent : $current_count"
    done
    
    # Vérification finale
    local final_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    log_success "Import terminé : $final_count communes importées"
    
    return 0
}

# Obtenir ou créer une liste
get_or_create_list() {
    local lists_response=$(curl -s -u "$API_USER:$API_TOKEN" "$API_URL/lists")
    local list_id=$(echo "$lists_response" | jq -r '.data[0].id // empty' 2>/dev/null)
    
    if [ -z "$list_id" ] || [ "$list_id" = "null" ]; then
        log_info "Création d'une nouvelle liste..."
        local create_response=$(curl -s -u "$API_USER:$API_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"name":"Communes France Complète","type":"public","optin":"single","tags":["communes","france","complete"]}' \
            "$API_URL/lists")
        
        list_id=$(echo "$create_response" | jq -r '.data.id // empty' 2>/dev/null)
        
        if [ -n "$list_id" ] && [ "$list_id" != "null" ]; then
            log_success "Liste créée avec ID: $list_id"
        else
            log_error "Échec de création de liste"
            return 1
        fi
    else
        log_info "Utilisation de la liste existante ID: $list_id"
    fi
    
    echo "$list_id"
}

# Extraction et mise à jour des données géographiques
extract_geo_data() {
    log_info "Extraction des données géographiques..."
    
    cat > /tmp/extract_geo_complete.sql << 'EOF'
-- Mise à jour des données géographiques depuis les attributs JSON

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

-- Statistiques détaillées
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

-- Répartition par département (top 10)
SELECT 
    department_code,
    COUNT(*) as communes_count,
    AVG(population) as avg_population
FROM subscribers 
WHERE department_code IS NOT NULL
GROUP BY department_code
ORDER BY communes_count DESC
LIMIT 10;

-- Échantillon des plus grandes communes
SELECT 
    name,
    department_code,
    population,
    attribs->>'nom_commune' as nom_commune
FROM subscribers 
WHERE population IS NOT NULL
ORDER BY population DESC
LIMIT 20;
EOF

    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < /tmp/extract_geo_complete.sql
    rm -f /tmp/extract_geo_complete.sql
    
    log_success "Extraction géographique terminée"
}

# Vérification finale
final_verification() {
    log_info "Vérification finale..."
    
    local total_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    local with_dept=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" | tr -d ' ')
    local with_pop=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL;" | tr -d ' ')
    
    echo ""
    log_success "🎉 IMPORT COMPLET TERMINÉ !"
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
    log_info "🔍 Vérifiez avec : ./verify-geo-targeting.sh"
    log_info "🎯 Interface web : http://localhost:9000"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Ce script va importer TOUTES les communes françaises (~81k)"
    echo ""
    echo "⚠️  ATTENTION :"
    echo "  • L'import peut prendre 30-60 minutes"
    echo "  • Assurez-vous d'avoir suffisamment d'espace disque"
    echo "  • L'opération va remplacer les données existantes"
    echo ""
    
    read -p "Continuer avec l'import complet ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Opération annulée."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉBUT DE L'IMPORT COMPLET"
    echo ""
    
    # Étapes d'import
    install_dependencies
    check_source_file
    convert_full_csv
    start_services
    import_by_batch
    extract_geo_data
    final_verification
    
    # Nettoyer les fichiers temporaires
    rm -f convert_csv.py batch_*.csv
    
    log_success "🎉 IMPORT COMPLET TERMINÉ AVEC SUCCÈS !"
}

# Exécuter
main "$@"