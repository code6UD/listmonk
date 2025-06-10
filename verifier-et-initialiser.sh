#!/bin/bash

# Script simple pour vérifier et initialiser Listmonk

echo "🔍 VÉRIFICATION ET INITIALISATION LISTMONK"
echo "=========================================="

# Configuration
COMPOSE_FILE="docker-compose.mairies.yml"
DB_CONTAINER="listmonk_mairies_db"
APP_CONTAINER="listmonk_mairies_app"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
API_URL="http://localhost:9000"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Étape 1 : Vérifier Docker
check_docker() {
    log_info "Vérification de Docker..."
    
    if ! docker ps &>/dev/null; then
        log_error "Docker non accessible"
        return 1
    fi
    
    log_success "Docker OK"
    return 0
}

# Étape 2 : Vérifier les conteneurs
check_containers() {
    log_info "Vérification des conteneurs..."
    
    if docker ps | grep -q "$DB_CONTAINER"; then
        log_success "Base de données en cours d'exécution"
    else
        log_warning "Base de données arrêtée"
        return 1
    fi
    
    if docker ps | grep -q "$APP_CONTAINER"; then
        log_success "Application en cours d'exécution"
    else
        log_warning "Application arrêtée"
        return 1
    fi
    
    return 0
}

# Étape 3 : Démarrer les services si nécessaire
start_services() {
    log_info "Démarrage des services..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Fichier $COMPOSE_FILE non trouvé"
        return 1
    fi
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log_info "Attente du démarrage (30 secondes)..."
    sleep 30
    
    return 0
}

# Étape 4 : Vérifier la base de données
check_database() {
    log_info "Vérification de la base de données..."
    
    # Test de connexion
    if ! docker exec "$DB_CONTAINER" pg_isready -U "$DB_USER" &>/dev/null; then
        log_error "PostgreSQL non prêt"
        return 1
    fi
    
    # Test de connexion avec authentification
    if ! docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        log_error "Connexion à la base de données échouée"
        return 1
    fi
    
    log_success "Base de données accessible"
    return 0
}

# Étape 5 : Vérifier l'initialisation Listmonk
check_listmonk_init() {
    log_info "Vérification de l'initialisation Listmonk..."
    
    # Vérifier si les tables existent
    local tables_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('subscribers', 'lists', 'campaigns');" | tr -d ' ')
    
    if [ "$tables_count" -eq 3 ]; then
        log_success "Listmonk initialisé"
        return 0
    else
        log_warning "Listmonk non initialisé ($tables_count/3 tables)"
        return 1
    fi
}

# Étape 6 : Initialiser Listmonk
init_listmonk() {
    log_info "Initialisation de Listmonk..."
    
    # Essayer d'initialiser via le conteneur
    if docker exec "$APP_CONTAINER" ./listmonk --install --yes; then
        log_success "Listmonk initialisé avec succès"
        return 0
    else
        log_error "Échec de l'initialisation"
        return 1
    fi
}

# Étape 7 : Vérifier l'interface web
check_web_interface() {
    log_info "Vérification de l'interface web..."
    
    if curl -s "$API_URL" &>/dev/null; then
        log_success "Interface web accessible"
        return 0
    else
        log_warning "Interface web non accessible"
        return 1
    fi
}

# Étape 8 : Tester l'API
test_api() {
    log_info "Test de l'API..."
    
    # Test avec les identifiants par défaut
    if curl -s -u "admin:listmonk" "$API_URL/api/health" &>/dev/null; then
        log_success "API accessible (admin:listmonk)"
        echo "admin:listmonk"
        return 0
    elif curl -s -u "admin:changeme" "$API_URL/api/health" &>/dev/null; then
        log_success "API accessible (admin:changeme)"
        echo "admin:changeme"
        return 0
    else
        log_warning "API non accessible avec les identifiants par défaut"
        return 1
    fi
}

# Afficher le résumé
show_summary() {
    echo ""
    log_info "📊 RÉSUMÉ"
    echo "========="
    
    echo ""
    echo "🌐 Accès :"
    echo "  • Interface : $API_URL"
    echo "  • Base de données : localhost:5433"
    
    echo ""
    echo "🔑 Identifiants :"
    echo "  • Interface : admin / listmonk (ou changeme)"
    echo "  • Base de données : $DB_USER / listmonk_mairies_2024"
    
    echo ""
    echo "🐳 Conteneurs :"
    docker ps --filter "name=listmonk_mairies" --format "table {{.Names}}\t{{.Status}}"
    
    echo ""
    echo "📊 Base de données :"
    local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    if [ -n "$count" ]; then
        echo "  • Abonnés : $count"
    else
        echo "  • Abonnés : 0 (base vide)"
    fi
    
    echo ""
    echo "🚀 Prochaines étapes :"
    echo "  1. Vérifiez l'interface : $API_URL"
    echo "  2. Lancez l'import : ./import-communes-simple.sh"
    echo "  3. Créez votre première campagne"
}

# Fonction principale
main() {
    echo ""
    
    # Vérifications de base
    if ! check_docker; then
        log_error "Docker requis"
        exit 1
    fi
    
    # Vérifier ou démarrer les conteneurs
    if ! check_containers; then
        log_info "Démarrage des services requis..."
        if ! start_services; then
            log_error "Impossible de démarrer les services"
            exit 1
        fi
        
        # Revérifier après démarrage
        if ! check_containers; then
            log_error "Services non démarrés"
            exit 1
        fi
    fi
    
    # Vérifier la base de données
    if ! check_database; then
        log_error "Problème de base de données"
        exit 1
    fi
    
    # Vérifier/initialiser Listmonk
    if ! check_listmonk_init; then
        log_info "Initialisation de Listmonk requise..."
        if ! init_listmonk; then
            log_error "Impossible d'initialiser Listmonk"
            exit 1
        fi
        
        # Attendre après initialisation
        log_info "Attente après initialisation (15 secondes)..."
        sleep 15
    fi
    
    # Vérifier l'interface web
    check_web_interface
    
    # Tester l'API
    local credentials=$(test_api)
    
    # Afficher le résumé
    show_summary
    
    echo ""
    if [ -n "$credentials" ]; then
        log_success "🎉 Système prêt ! Vous pouvez maintenant importer les communes."
        echo ""
        echo "▶️  Commande suivante : ./import-communes-simple.sh"
    else
        log_warning "⚠️  Système partiellement prêt. Vérifiez l'interface web."
    fi
    
    echo ""
}

# Exécuter
main "$@"