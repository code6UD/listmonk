#!/bin/bash

# Script de diagnostic rapide pour identifier les problèmes

echo "🔍 DIAGNOSTIC RAPIDE"
echo "==================="

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

echo ""
log_info "1. État de Docker"
echo "----------------"

if command -v docker &> /dev/null; then
    log_success "Docker installé"
    
    if docker ps &> /dev/null; then
        log_success "Docker en cours d'exécution"
        
        echo ""
        echo "Conteneurs actifs :"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        echo "Tous les conteneurs :"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
        
    else
        log_error "Docker non démarré"
        echo "Solution : Démarrez Docker avec 'systemctl start docker' ou 'dockerd &'"
    fi
else
    log_error "Docker non installé"
    echo "Solution : Installez Docker"
fi

echo ""
log_info "2. Vérification des ports"
echo "------------------------"

if netstat -tlnp 2>/dev/null | grep -q ":9000"; then
    log_success "Port 9000 (Listmonk) en écoute"
else
    log_warning "Port 9000 (Listmonk) non en écoute"
fi

if netstat -tlnp 2>/dev/null | grep -q ":5432"; then
    log_success "Port 5432 (PostgreSQL) en écoute"
else
    log_warning "Port 5432 (PostgreSQL) non en écoute"
fi

echo ""
log_info "3. Test de connectivité"
echo "----------------------"

if curl -s http://localhost:9000 &>/dev/null; then
    log_success "Interface Listmonk accessible"
else
    log_error "Interface Listmonk non accessible"
fi

echo ""
log_info "4. Fichiers de configuration"
echo "---------------------------"

if [ -f "docker-compose.yml" ]; then
    log_success "docker-compose.yml présent"
else
    log_warning "docker-compose.yml manquant"
fi

if [ -f "config.toml" ]; then
    log_success "config.toml présent"
else
    log_warning "config.toml manquant"
fi

if [ -f "mairielist.csv" ]; then
    local lines=$(wc -l < mairielist.csv)
    log_success "mairielist.csv présent ($lines lignes)"
else
    log_error "mairielist.csv manquant"
fi

echo ""
log_info "5. Test de base de données"
echo "-------------------------"

# Essayer de trouver et tester les conteneurs de base de données
local db_containers=("listmonk_db" "listmonk_mairies_db" "postgres")
local db_found=false

for container in "${db_containers[@]}"; do
    if docker ps | grep -q "$container"; then
        log_info "Test du conteneur $container..."
        
        if docker exec "$container" pg_isready &>/dev/null; then
            log_success "PostgreSQL prêt dans $container"
            
            # Essayer de se connecter
            if docker exec "$container" psql -U listmonk -d listmonk -c "SELECT 1;" &>/dev/null; then
                log_success "Connexion réussie (listmonk/listmonk)"
                db_found=true
            elif docker exec "$container" psql -U listmonk_mairies -d listmonk_mairies -c "SELECT 1;" &>/dev/null; then
                log_success "Connexion réussie (listmonk_mairies/listmonk_mairies)"
                db_found=true
            elif docker exec "$container" psql -U postgres -d postgres -c "SELECT 1;" &>/dev/null; then
                log_success "Connexion réussie (postgres/postgres)"
                db_found=true
            else
                log_warning "PostgreSQL prêt mais connexion échouée"
            fi
        else
            log_warning "PostgreSQL non prêt dans $container"
        fi
        break
    fi
done

if [ "$db_found" = false ]; then
    log_error "Aucune base de données fonctionnelle trouvée"
fi

echo ""
log_info "6. Recommandations"
echo "----------------"

if ! docker ps &> /dev/null; then
    echo "🔧 Démarrez Docker :"
    echo "   systemctl start docker"
    echo "   # ou"
    echo "   dockerd > /tmp/docker.log 2>&1 &"
    echo ""
fi

if ! docker ps | grep -q "listmonk"; then
    echo "🔧 Démarrez les services :"
    echo "   docker-compose up -d"
    echo "   # ou"
    echo "   ./fix-database-connection.sh"
    echo ""
fi

if [ "$db_found" = false ]; then
    echo "🔧 Corrigez la base de données :"
    echo "   ./fix-database-connection.sh"
    echo ""
fi

if ! curl -s http://localhost:9000 &>/dev/null; then
    echo "🔧 Vérifiez l'interface :"
    echo "   docker logs listmonk_app"
    echo "   docker-compose restart"
    echo ""
fi

echo "🚀 Scripts utiles :"
echo "   ./fix-database-connection.sh  - Corriger les problèmes de DB"
echo "   ./import-all-communes.sh      - Import complet"
echo "   ./check-current-import.sh     - Vérifier l'état"
echo "   ./final-verification.sh       - Vérification complète"

echo ""