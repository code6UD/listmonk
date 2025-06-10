#!/bin/bash

# Script de vérification spécifique pour docker-compose.mairies.yml

echo "🔍 VÉRIFICATION SYSTÈME MAIRIES"
echo "==============================="

# Configuration spécifique
DB_CONTAINER="listmonk_mairies_db"
APP_CONTAINER="listmonk_mairies_app"
REDIS_CONTAINER="listmonk_mairies_redis"
DB_USER="listmonk_mairies"
DB_NAME="listmonk_mairies"
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

score=0
total_tests=0

test_result() {
    local result=$1
    local message="$2"
    
    total_tests=$((total_tests + 1))
    
    if [ "$result" -eq 0 ]; then
        log_success "$message"
        score=$((score + 1))
    else
        log_error "$message"
    fi
}

echo ""
log_info "🐳 Vérification Docker et Compose"
echo "--------------------------------"

# Docker
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    test_result 0 "Docker en cours d'exécution"
else
    test_result 1 "Docker non accessible"
fi

# Fichier compose
if [ -f "$COMPOSE_FILE" ]; then
    test_result 0 "Fichier $COMPOSE_FILE présent"
else
    test_result 1 "Fichier $COMPOSE_FILE manquant"
fi

echo ""
log_info "🏗️ État des Conteneurs"
echo "---------------------"

# Conteneur DB
if docker ps | grep -q "$DB_CONTAINER"; then
    test_result 0 "Base de données PostgreSQL en cours d'exécution"
else
    test_result 1 "Base de données PostgreSQL arrêtée"
fi

# Conteneur App
if docker ps | grep -q "$APP_CONTAINER"; then
    test_result 0 "Application Listmonk en cours d'exécution"
else
    test_result 1 "Application Listmonk arrêtée"
fi

# Conteneur Redis
if docker ps | grep -q "$REDIS_CONTAINER"; then
    test_result 0 "Redis en cours d'exécution"
else
    test_result 1 "Redis arrêté"
fi

echo ""
log_info "🌐 Vérification Réseau"
echo "---------------------"

# Interface web
if curl -s http://localhost:9000 &>/dev/null; then
    test_result 0 "Interface web Listmonk accessible"
else
    test_result 1 "Interface web Listmonk non accessible"
fi

# Port base de données
if netstat -tlnp 2>/dev/null | grep -q ":5433"; then
    test_result 0 "Port PostgreSQL (5433) en écoute"
else
    test_result 1 "Port PostgreSQL (5433) non en écoute"
fi

echo ""
log_info "🗄️ Vérification Base de Données"
echo "-------------------------------"

# Connexion DB
if docker ps | grep -q "$DB_CONTAINER" && docker exec "$DB_CONTAINER" pg_isready -U "$DB_USER" &>/dev/null; then
    test_result 0 "PostgreSQL prêt"
    
    # Test de connexion
    if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        test_result 0 "Connexion à la base de données"
        
        # Tables Listmonk
        if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'subscribers';" | grep -q "1"; then
            test_result 0 "Tables Listmonk initialisées"
            
            # Compter les abonnés
            count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
            if [ -n "$count" ] && [ "$count" -gt 0 ]; then
                test_result 0 "Communes importées ($count)"
                
                # Vérifier les départements
                dept_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(DISTINCT attribs->>'departement_numero') FROM subscribers WHERE attribs->>'departement_numero' IS NOT NULL;" 2>/dev/null | tr -d ' ')
                if [ -n "$dept_count" ] && [ "$dept_count" -gt 0 ]; then
                    test_result 0 "Départements extraits ($dept_count)"
                else
                    test_result 1 "Départements non extraits"
                fi
                
                # Vérifier la population
                pop_count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM subscribers WHERE attribs->>'population_commune' IS NOT NULL;" 2>/dev/null | tr -d ' ')
                if [ -n "$pop_count" ] && [ "$pop_count" -gt 0 ]; then
                    test_result 0 "Population renseignée ($pop_count communes)"
                else
                    test_result 1 "Population non renseignée"
                fi
                
            else
                test_result 1 "Aucune commune importée"
            fi
        else
            test_result 1 "Tables Listmonk non initialisées"
        fi
    else
        test_result 1 "Connexion à la base de données échouée"
    fi
else
    test_result 1 "PostgreSQL non prêt"
fi

echo ""
log_info "📁 Vérification Fichiers"
echo "-----------------------"

# Fichier CSV
if [ -f "mairielist.csv" ]; then
    csv_lines=$(wc -l < mairielist.csv)
    test_result 0 "Fichier source mairielist.csv présent ($csv_lines lignes)"
else
    test_result 1 "Fichier source mairielist.csv manquant"
fi

# Fichier .env
if [ -f ".env" ]; then
    test_result 0 "Fichier .env présent"
else
    test_result 1 "Fichier .env manquant"
fi

echo ""
log_info "🔧 Scripts Disponibles"
echo "---------------------"

scripts=("fix-mairies-database.sh" "import-mairies-fixed.sh" "check-mairies-status.sh")
for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        test_result 0 "Script $script exécutable"
    else
        test_result 1 "Script $script manquant ou non exécutable"
    fi
done

echo ""
log_info "📊 RÉSULTATS DE LA VÉRIFICATION"
echo "==============================="

percentage=$((score * 100 / total_tests))

if [ $percentage -ge 80 ]; then
    log_success "Score : $score/$total_tests ($percentage%) - Système opérationnel ✅"
elif [ $percentage -ge 60 ]; then
    log_warning "Score : $score/$total_tests ($percentage%) - Système partiellement fonctionnel ⚠️"
else
    log_error "Score : $score/$total_tests ($percentage%) - Système nécessite des corrections ❌"
fi

echo ""
log_info "🔧 Actions Recommandées"
echo "----------------------"

if [ $score -lt $total_tests ]; then
    echo ""
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        echo "🔧 Démarrer les services :"
        echo "   docker-compose -f $COMPOSE_FILE up -d"
        echo ""
    fi
    
    if ! docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null 2>&1; then
        echo "🔧 Corriger la base de données :"
        echo "   ./fix-mairies-database.sh"
        echo ""
    fi
    
    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        echo "🔧 Importer les communes :"
        echo "   ./import-mairies-fixed.sh"
        echo ""
    fi
    
    echo "🔧 Diagnostic complet :"
    echo "   ./fix-mairies-database.sh"
    echo ""
fi

echo "🌐 Accès aux services :"
echo "   • Interface : http://localhost:9000"
echo "   • Base de données : localhost:5433"
echo "   • Adminer : http://localhost:8082"

echo ""
log_info "📚 Documentation"
echo "---------------"
echo "   • TROUBLESHOOTING_DATABASE.md : Guide de résolution"
echo "   • README_IMPORT_COMPLET.md : Guide complet"

echo ""