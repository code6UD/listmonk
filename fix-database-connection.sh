#!/bin/bash

# Script pour diagnostiquer et corriger les problèmes de base de données

echo "🔧 DIAGNOSTIC ET CORRECTION BASE DE DONNÉES"
echo "==========================================="

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
        log_warning "Docker n'est pas en cours d'exécution, démarrage..."
        
        # Essayer de démarrer Docker
        if command -v systemctl &> /dev/null; then
            systemctl start docker
        else
            # Démarrer Docker manuellement
            dockerd > /tmp/docker.log 2>&1 &
            sleep 10
        fi
        
        # Vérifier à nouveau
        if ! docker ps &> /dev/null; then
            log_error "Impossible de démarrer Docker"
            return 1
        fi
    fi
    
    log_success "Docker fonctionne"
    return 0
}

# Vérifier les conteneurs
check_containers() {
    log_info "Vérification des conteneurs..."
    
    # Lister tous les conteneurs
    echo "Conteneurs existants :"
    docker ps -a
    
    echo ""
    
    # Vérifier les conteneurs spécifiques
    local db_container=""
    local app_container=""
    
    # Chercher les conteneurs de base de données
    if docker ps -a | grep -q "postgres"; then
        db_container=$(docker ps -a | grep postgres | awk '{print $1}' | head -1)
        log_info "Conteneur PostgreSQL trouvé : $db_container"
    elif docker ps -a | grep -q "listmonk.*db"; then
        db_container=$(docker ps -a | grep "listmonk.*db" | awk '{print $1}' | head -1)
        log_info "Conteneur DB Listmonk trouvé : $db_container"
    else
        log_warning "Aucun conteneur de base de données trouvé"
    fi
    
    # Chercher les conteneurs Listmonk
    if docker ps -a | grep -q "listmonk" && ! docker ps -a | grep -q "listmonk.*db"; then
        app_container=$(docker ps -a | grep listmonk | grep -v db | awk '{print $1}' | head -1)
        log_info "Conteneur Listmonk trouvé : $app_container"
    fi
    
    echo "DB_CONTAINER=$db_container" > /tmp/containers.env
    echo "APP_CONTAINER=$app_container" >> /tmp/containers.env
    
    return 0
}

# Démarrer les conteneurs
start_containers() {
    log_info "Démarrage des conteneurs..."
    
    source /tmp/containers.env
    
    # Si nous avons un docker-compose.yml, l'utiliser
    if [ -f "docker-compose.yml" ]; then
        log_info "Utilisation de docker-compose..."
        docker-compose down
        docker-compose up -d
        
        log_info "Attente du démarrage des services (30 secondes)..."
        sleep 30
        
    else
        log_info "Démarrage manuel des conteneurs..."
        
        # Démarrer la base de données en premier
        if [ -n "$DB_CONTAINER" ]; then
            log_info "Démarrage du conteneur de base de données..."
            docker start "$DB_CONTAINER"
            sleep 15
        fi
        
        # Puis l'application
        if [ -n "$APP_CONTAINER" ]; then
            log_info "Démarrage du conteneur Listmonk..."
            docker start "$APP_CONTAINER"
            sleep 10
        fi
    fi
    
    log_success "Conteneurs démarrés"
}

# Créer une configuration Docker si nécessaire
create_docker_config() {
    log_info "Création de la configuration Docker..."
    
    if [ ! -f "docker-compose.yml" ]; then
        log_info "Création de docker-compose.yml..."
        
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  listmonk_db:
    image: postgres:13
    container_name: listmonk_db
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk
    volumes:
      - listmonk_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  listmonk_app:
    image: listmonk/listmonk:latest
    container_name: listmonk_app
    depends_on:
      listmonk_db:
        condition: service_healthy
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_db__host: "listmonk_db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk"
      LISTMONK_db__password: "listmonk"
      LISTMONK_db__database: "listmonk"
      LISTMONK_db__ssl_mode: "disable"
    ports:
      - "9000:9000"
    volumes:
      - ./config.toml:/listmonk/config.toml:ro
    command: ["./listmonk", "--config", "config.toml"]

volumes:
  listmonk_data:
EOF
    fi
    
    if [ ! -f "config.toml" ]; then
        log_info "Création de config.toml..."
        
        cat > config.toml << 'EOF'
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "listmonk"

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
EOF
    fi
    
    log_success "Configuration Docker créée"
}

# Tester la connexion à la base de données
test_database_connection() {
    log_info "Test de connexion à la base de données..."
    
    # Essayer différents noms de conteneurs
    local containers=("listmonk_db" "listmonk_mairies_db" "postgres")
    local db_found=false
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            log_info "Test de connexion au conteneur $container..."
            
            # Essayer différentes combinaisons d'utilisateur/base
            local users=("listmonk" "listmonk_mairies" "postgres")
            local databases=("listmonk" "listmonk_mairies" "postgres")
            
            for user in "${users[@]}"; do
                for db in "${databases[@]}"; do
                    if docker exec "$container" psql -U "$user" -d "$db" -c "SELECT 1;" &>/dev/null; then
                        log_success "Connexion réussie : $container / $user / $db"
                        echo "DB_CONTAINER=$container" > /tmp/db_config.env
                        echo "DB_USER=$user" >> /tmp/db_config.env
                        echo "DB_NAME=$db" >> /tmp/db_config.env
                        db_found=true
                        break 2
                    fi
                done
            done
            
            if [ "$db_found" = true ]; then
                break
            fi
        fi
    done
    
    if [ "$db_found" = false ]; then
        log_error "Aucune connexion de base de données fonctionnelle trouvée"
        return 1
    fi
    
    return 0
}

# Initialiser la base de données Listmonk
init_listmonk_db() {
    log_info "Initialisation de la base de données Listmonk..."
    
    source /tmp/db_config.env
    
    # Vérifier si Listmonk est initialisé
    if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'subscribers';" | grep -q "1"; then
        log_success "Base de données Listmonk déjà initialisée"
        return 0
    fi
    
    # Initialiser Listmonk
    log_info "Initialisation de Listmonk..."
    
    # Trouver le conteneur Listmonk
    local app_container=$(docker ps | grep listmonk | grep -v db | awk '{print $1}' | head -1)
    
    if [ -n "$app_container" ]; then
        docker exec "$app_container" ./listmonk --install --yes
        log_success "Listmonk initialisé"
    else
        log_warning "Conteneur Listmonk non trouvé pour l'initialisation"
    fi
    
    return 0
}

# Vérifier l'état final
final_check() {
    log_info "Vérification finale..."
    
    # Vérifier les conteneurs
    echo "État des conteneurs :"
    docker ps
    
    echo ""
    
    # Vérifier la connexion web
    if curl -s http://localhost:9000 &>/dev/null; then
        log_success "Interface web accessible : http://localhost:9000"
    else
        log_warning "Interface web non accessible"
    fi
    
    # Vérifier la base de données
    if [ -f "/tmp/db_config.env" ]; then
        source /tmp/db_config.env
        
        local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
        
        if [ -n "$count" ] && [ "$count" -gt 0 ]; then
            log_success "Base de données fonctionnelle avec $count abonnés"
        else
            log_info "Base de données fonctionnelle mais vide"
        fi
    fi
    
    echo ""
    log_info "🎯 Prochaines étapes :"
    echo "  1. Vérifiez l'interface : http://localhost:9000"
    echo "  2. Lancez l'import : ./import-all-communes.sh"
    echo "  3. Vérifiez les données : ./check-current-import.sh"
}

# Fonction principale
main() {
    echo ""
    log_info "Diagnostic et correction des problèmes de base de données"
    echo ""
    
    # Étapes de diagnostic et correction
    check_docker || exit 1
    check_containers
    create_docker_config
    start_containers
    
    # Attendre que les services soient prêts
    log_info "Attente de la stabilisation des services (20 secondes)..."
    sleep 20
    
    test_database_connection || {
        log_error "Impossible d'établir une connexion à la base de données"
        echo ""
        log_info "Essayez de redémarrer complètement :"
        echo "  docker-compose down"
        echo "  docker-compose up -d"
        exit 1
    }
    
    init_listmonk_db
    final_check
    
    echo ""
    log_success "🎉 Diagnostic et correction terminés !"
    echo ""
    
    # Nettoyer les fichiers temporaires
    rm -f /tmp/containers.env /tmp/db_config.env
}

# Exécuter
main "$@"