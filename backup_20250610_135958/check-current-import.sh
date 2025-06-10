#!/bin/bash

# Script de vérification rapide de l'état actuel de l'import

echo "🔍 VÉRIFICATION DE L'ÉTAT ACTUEL"
echo "==============================="

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

# Vérifier si Docker fonctionne
if ! docker ps > /dev/null 2>&1; then
    log_error "Docker n'est pas en cours d'exécution"
    exit 1
fi

# Vérifier si le conteneur de base de données existe
if ! docker ps -a | grep -q "$DB_CONTAINER"; then
    log_warning "Conteneur de base de données non trouvé"
    log_info "Lancement du script d'import complet..."
    exit 1
fi

# Vérifier si le conteneur est en cours d'exécution
if ! docker ps | grep -q "$DB_CONTAINER"; then
    log_warning "Conteneur de base de données arrêté, démarrage..."
    docker start "$DB_CONTAINER"
    sleep 10
fi

# Vérifier la connexion à la base de données
if ! docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Impossible de se connecter à la base de données"
    exit 1
fi

log_success "Connexion à la base de données établie"

# Statistiques actuelles
echo ""
log_info "📊 Statistiques actuelles :"

# Nombre total d'abonnés
total_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
if [ -n "$total_count" ] && [ "$total_count" -gt 0 ]; then
    echo "  • Total communes importées : $total_count"
else
    log_warning "Aucune commune trouvée dans la base de données"
    echo ""
    log_info "Fichiers CSV disponibles :"
    ls -la *.csv | grep -E "(mairielist|commune)" | while read line; do
        echo "    $line"
    done
    echo ""
    log_info "Pour importer toutes les communes, exécutez :"
    log_info "./import-all-communes.sh"
    exit 0
fi

# Communes avec département
with_dept=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
echo "  • Avec département : ${with_dept:-0}"

# Communes avec population
with_pop=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL AND population > 0;" 2>/dev/null | tr -d ' ')
echo "  • Avec population : ${with_pop:-0}"

# Communes avec code INSEE
with_insee=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE commune_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
echo "  • Avec code INSEE : ${with_insee:-0}"

echo ""

# Analyse de la complétude
if [ "$total_count" -lt 10000 ]; then
    log_warning "Import très incomplet (< 10k communes)"
    echo "  📁 Fichier source disponible : $(wc -l < mairielist.csv) lignes"
    echo "  🎯 Objectif : ~81k communes"
    echo ""
    log_info "Pour importer toutes les communes :"
    log_info "./import-all-communes.sh"
elif [ "$total_count" -lt 50000 ]; then
    log_warning "Import partiel ($total_count communes)"
    echo "  📁 Fichier source disponible : $(wc -l < mairielist.csv) lignes"
    echo "  🎯 Objectif : ~81k communes"
    echo ""
    log_info "Pour compléter l'import :"
    log_info "./import-all-communes.sh"
elif [ "$total_count" -lt 75000 ]; then
    log_success "Import presque complet ($total_count communes)"
    echo "  📁 Fichier source disponible : $(wc -l < mairielist.csv) lignes"
    echo "  🎯 Objectif : ~81k communes"
else
    log_success "Import complet ! ($total_count communes)"
fi

# Top 10 des départements
echo ""
log_info "🗺️  Top 10 départements (par nombre de communes) :"
docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT 
    COALESCE(department_code, 'Non défini') as dept,
    COUNT(*) as count
FROM subscribers 
GROUP BY department_code
ORDER BY count DESC
LIMIT 10;" 2>/dev/null | while read line; do
    echo "    $line"
done

# Échantillon des plus grandes communes
echo ""
log_info "🏙️  Top 10 des plus grandes communes :"
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

# Vérifier l'interface web
if curl -s http://localhost:9000 > /dev/null 2>&1; then
    log_success "Interface web accessible : http://localhost:9000"
else
    log_warning "Interface web non accessible"
    log_info "Démarrez les services avec : docker-compose up -d"
fi

echo ""
log_info "🔧 Commandes utiles :"
echo "  • Vérification complète : ./verify-geo-targeting.sh"
echo "  • Import complet : ./import-all-communes.sh"
echo "  • Interface web : http://localhost:9000"
echo ""