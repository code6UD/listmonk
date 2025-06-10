#!/bin/bash

# Script de diagnostic et correction spécifique pour docker-compose.mairies.yml

echo "🔧 DIAGNOSTIC ET CORRECTION - CONFIGURATION MAIRIES"
echo "=================================================="

# Configuration spécifique aux mairies
DB_CONTAINER="listmonk_mairies_db"
APP_CONTAINER="listmonk_mairies_app"
REDIS_CONTAINER="listmonk_mairies_redis"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
DB_PASSWORD="listmonk_mairies_2024"
COMPOSE_FILE="docker-compose.mairies.yml"

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

# Vérifier Docker
check_docker() {
    log_info "Vérification de Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        log_error "Docker n'est pas en cours d'exécution"
        return 1
    fi
    
    log_success "Docker fonctionne"
    return 0
}

# Vérifier le fichier compose
check_compose_file() {
    log_info "Vérification du fichier docker-compose..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Fichier $COMPOSE_FILE non trouvé"
        return 1
    fi
    
    log_success "Fichier $COMPOSE_FILE trouvé"
    return 0
}

# État actuel des conteneurs
check_containers() {
    log_info "État des conteneurs mairies..."
    
    echo ""
    echo "Conteneurs mairies :"
    docker ps -a --filter "name=listmonk_mairies" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    
    # Vérifier chaque conteneur
    for container in "$DB_CONTAINER" "$APP_CONTAINER" "$REDIS_CONTAINER"; do
        if docker ps | grep -q "$container"; then
            log_success "$container en cours d'exécution"
        elif docker ps -a | grep -q "$container"; then
            log_warning "$container arrêté"
        else
            log_error "$container non trouvé"
        fi
    done
}

# Redémarrer les services
restart_services() {
    log_info "Redémarrage des services mairies..."
    
    # Arrêter les services
    log_info "Arrêt des services..."
    docker-compose -f "$COMPOSE_FILE" down
    
    # Attendre un peu
    sleep 5
    
    # Redémarrer
    log_info "Démarrage des services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Attendre le démarrage
    log_info "Attente du démarrage des services (45 secondes)..."
    sleep 45
    
    log_success "Services redémarrés"
}

# Tester la connexion à la base de données
test_database() {
    log_info "Test de connexion à la base de données..."
    
    # Vérifier que le conteneur DB est en cours d'exécution
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log_error "Conteneur $DB_CONTAINER non en cours d'exécution"
        return 1
    fi
    
    # Tester pg_isready
    if docker exec "$DB_CONTAINER" pg_isready -U "$DB_USER" &>/dev/null; then
        log_success "PostgreSQL prêt"
    else
        log_error "PostgreSQL non prêt"
        return 1
    fi
    
    # Tester la connexion
    if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        log_success "Connexion à la base de données réussie"
        
        # Vérifier les tables Listmonk
        if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'subscribers';" | grep -q "1"; then
            log_success "Tables Listmonk présentes"
            
            # Compter les abonnés
            local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
            if [ -n "$count" ] && [ "$count" -gt 0 ]; then
                log_success "Abonnés trouvés : $count"
            else
                log_info "Base de données vide (0 abonnés)"
            fi
        else
            log_warning "Tables Listmonk non initialisées"
        fi
        
        return 0
    else
        log_error "Connexion à la base de données échouée"
        return 1
    fi
}

# Initialiser Listmonk si nécessaire
init_listmonk() {
    log_info "Vérification de l'initialisation Listmonk..."
    
    # Vérifier si l'app est en cours d'exécution
    if ! docker ps | grep -q "$APP_CONTAINER"; then
        log_error "Conteneur $APP_CONTAINER non en cours d'exécution"
        return 1
    fi
    
    # Vérifier si Listmonk est initialisé
    if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'subscribers';" | grep -q "1"; then
        log_success "Listmonk déjà initialisé"
        return 0
    fi
    
    # Initialiser Listmonk
    log_info "Initialisation de Listmonk..."
    docker exec "$APP_CONTAINER" ./listmonk --install --yes
    
    if [ $? -eq 0 ]; then
        log_success "Listmonk initialisé avec succès"
    else
        log_error "Échec de l'initialisation Listmonk"
        return 1
    fi
    
    return 0
}

# Vérifier l'interface web
check_web_interface() {
    log_info "Vérification de l'interface web..."
    
    if curl -s http://localhost:9000 &>/dev/null; then
        log_success "Interface web accessible : http://localhost:9000"
    else
        log_warning "Interface web non accessible"
        
        # Vérifier les logs de l'app
        log_info "Logs de l'application :"
        docker logs "$APP_CONTAINER" --tail 10
    fi
}

# Créer un script d'import adapté
create_import_script() {
    log_info "Création du script d'import adapté..."
    
    cat > import-mairies-fixed.sh << 'EOF'
#!/bin/bash

# Script d'import spécifique pour la configuration mairies

echo "🏛️ IMPORT COMMUNES - CONFIGURATION MAIRIES"
echo "=========================================="

# Configuration
DB_CONTAINER="listmonk_mairies_db"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
API_URL="http://localhost:9000/api"
API_USER="admin"
API_PASS="changeme"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Vérifier la connexion DB
if ! docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    log_error "Connexion à la base de données échouée"
    exit 1
fi

log_success "Connexion à la base de données OK"

# Vérifier l'API
if ! curl -s -u "$API_USER:$API_PASS" "$API_URL/health" &>/dev/null; then
    log_error "API Listmonk non accessible"
    exit 1
fi

log_success "API Listmonk accessible"

# Compter les lignes du CSV
if [ -f "mairielist.csv" ]; then
    local csv_lines=$(wc -l < mairielist.csv)
    log_info "Fichier CSV : $csv_lines lignes"
else
    log_error "Fichier mairielist.csv non trouvé"
    exit 1
fi

# Obtenir ou créer une liste
log_info "Gestion des listes..."
lists_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/lists")
list_id=$(echo "$lists_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$list_id" ]; then
    log_info "Création d'une nouvelle liste..."
    create_response=$(curl -s -u "$API_USER:$API_PASS" \
        -H "Content-Type: application/json" \
        -d '{"name":"Communes France","type":"public","optin":"single","tags":["communes"]}' \
        "$API_URL/lists")
    
    list_id=$(echo "$create_response" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    log_success "Liste créée avec ID: $list_id"
else
    log_info "Utilisation de la liste existante ID: $list_id"
fi

# Préparer le CSV pour l'import
log_info "Préparation du CSV..."
python3 << 'PYTHON_EOF'
import csv
import json

def prepare_csv():
    input_file = 'mairielist.csv'
    output_file = 'mairies-import.csv'
    
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
        
        print(f"CSV préparé : {count} communes")

if __name__ == "__main__":
    prepare_csv()
PYTHON_EOF

# Lancer l'import
log_info "Lancement de l'import..."
import_response=$(curl -s -u "$API_USER:$API_PASS" \
    -F "file=@mairies-import.csv" \
    -F "params={\"list_ids\":[$list_id],\"overwrite\":true,\"delim\":\",\",\"mode\":\"subscribe\"}" \
    "$API_URL/import/subscribers")

log_info "Import lancé, attente..."
sleep 30

# Vérifier le résultat
count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
log_success "Import terminé : $count communes"

# Nettoyer
rm -f mairies-import.csv

echo ""
log_success "🎉 Import terminé !"
echo "Interface : http://localhost:9000"
EOF

    chmod +x import-mairies-fixed.sh
    log_success "Script d'import créé : import-mairies-fixed.sh"
}

# Afficher les informations de connexion
show_connection_info() {
    log_info "Informations de connexion..."
    
    echo ""
    echo "🔗 Accès aux services :"
    echo "  • Interface Listmonk : http://localhost:9000"
    echo "  • Base de données : localhost:5433"
    echo "  • Redis : localhost:6380"
    echo "  • Adminer (dev) : http://localhost:8082"
    echo ""
    echo "🔑 Identifiants par défaut :"
    echo "  • Listmonk : admin / changeme"
    echo "  • Base de données : listmonk_mairies / listmonk_mairies_2024"
    echo ""
    echo "🐳 Conteneurs :"
    echo "  • App : $APP_CONTAINER"
    echo "  • DB : $DB_CONTAINER"
    echo "  • Redis : $REDIS_CONTAINER"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_info "Diagnostic et correction pour la configuration mairies"
    echo ""
    
    # Vérifications
    check_docker || exit 1
    check_compose_file || exit 1
    
    # État actuel
    check_containers
    
    echo ""
    read -p "Redémarrer les services ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_services
        check_containers
    fi
    
    echo ""
    
    # Tests
    if test_database; then
        init_listmonk
        check_web_interface
        create_import_script
        
        echo ""
        log_success "🎉 Système opérationnel !"
        
        show_connection_info
        
        echo "🚀 Prochaines étapes :"
        echo "  1. Vérifiez l'interface : http://localhost:9000"
        echo "  2. Lancez l'import : ./import-mairies-fixed.sh"
        echo "  3. Vérifiez les données importées"
        
    else
        log_error "Problème de base de données non résolu"
        echo ""
        echo "🔧 Actions manuelles :"
        echo "  docker-compose -f $COMPOSE_FILE logs db"
        echo "  docker-compose -f $COMPOSE_FILE restart"
    fi
    
    echo ""
}

# Exécuter
main "$@"