#!/bin/bash

# Script de vérification finale du système complet

echo "🔍 VÉRIFICATION FINALE DU SYSTÈME"
echo "=================================="

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

# Compteurs
total_checks=0
passed_checks=0

check() {
    total_checks=$((total_checks + 1))
    if eval "$1"; then
        log_success "$2"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        log_error "$2"
        return 1
    fi
}

# Vérifications Docker
echo ""
log_info "🐳 Vérification Docker"
check "docker ps | grep -q 'listmonk_db\|postgres'" "Base de données PostgreSQL en cours d'exécution"
check "docker ps | grep -q listmonk_app" "Application Listmonk en cours d'exécution"

# Vérifications réseau
echo ""
log_info "🌐 Vérification Réseau"
check "curl -s http://localhost:9000 > /dev/null" "Interface web Listmonk accessible"
check "curl -s http://localhost:9000/public/geo-targeting.js > /dev/null" "Script de ciblage géographique accessible"

# Vérifications base de données
echo ""
log_info "🗄️ Vérification Base de Données"
check "docker exec listmonk_db psql -U listmonk -d listmonk -c 'SELECT 1;' > /dev/null 2>&1" "Connexion à la base de données"

# Compter les communes
communes_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
check "[ '$communes_count' -gt 30000 ]" "Nombre de communes importées ($communes_count)"

# Vérifier les données géographiques
with_dept=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
check "[ '$with_dept' -gt 30000 ]" "Communes avec département ($with_dept)"

with_pop=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL;" 2>/dev/null | tr -d ' ')
check "[ '$with_pop' -gt 30000 ]" "Communes avec population ($with_pop)"

# Vérifier la liste
list_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM lists WHERE name = 'Communes France';" 2>/dev/null | tr -d ' ')
check "[ '$list_count' -eq 1 ]" "Liste 'Communes France' créée"

# Vérifications fichiers
echo ""
log_info "📁 Vérification Fichiers"
check "[ -f 'mairielist.csv' ]" "Fichier source mairielist.csv présent"
check "[ -f 'geo-targeting.js' ]" "Script de ciblage géographique créé"
check "[ -f 'bookmarklet.html' ]" "Bookmarklet d'activation créé"
check "[ -f 'INTEGRATION_COMPLETE_FINALE.md' ]" "Documentation finale créée"

# Vérifications scripts
echo ""
log_info "🔧 Vérification Scripts"
check "[ -x 'check-current-import.sh' ]" "Script de vérification exécutable"
check "[ -x 'import-fixed.sh' ]" "Script d'import exécutable"
check "[ -x 'analyze-csv.sh' ]" "Script d'analyse exécutable"
check "[ -x 'create-geo-targeting-interface.sh' ]" "Script d'interface exécutable"

# Test de quelques départements
echo ""
log_info "🗺️ Vérification Départements"
paris_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code = '75';" 2>/dev/null | tr -d ' ')
check "[ '$paris_count' -gt 0 ]" "Communes de Paris (75) : $paris_count"

nord_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code = '59';" 2>/dev/null | tr -d ' ')
check "[ '$nord_count' -gt 500 ]" "Communes du Nord (59) : $nord_count"

# Test de population
echo ""
log_info "👥 Vérification Population"
big_cities=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE population > 100000;" 2>/dev/null | tr -d ' ')
check "[ '$big_cities' -gt 50 ]" "Grandes villes (>100k hab) : $big_cities"

small_cities=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE population < 1000;" 2>/dev/null | tr -d ' ')
check "[ '$small_cities' -gt 15000 ]" "Petites communes (<1k hab) : $small_cities"

# Affichage des résultats
echo ""
echo "📊 RÉSULTATS DE LA VÉRIFICATION"
echo "================================"

if [ "$passed_checks" -eq "$total_checks" ]; then
    log_success "Tous les tests passés : $passed_checks/$total_checks ✅"
    echo ""
    log_success "🎉 SYSTÈME ENTIÈREMENT OPÉRATIONNEL !"
    echo ""
    echo "📋 Résumé du système :"
    echo "  • Communes importées : $communes_count"
    echo "  • Avec département : $with_dept"
    echo "  • Avec population : $with_pop"
    echo "  • Interface web : http://localhost:9000"
    echo "  • Script de ciblage : Activé"
    echo ""
    echo "🎯 Prochaines étapes :"
    echo "  1. Ouvrez bookmarklet.html dans votre navigateur"
    echo "  2. Glissez le lien dans vos favoris"
    echo "  3. Allez sur http://localhost:9000"
    echo "  4. Activez l'interface de ciblage géographique"
    echo ""
    echo "🇫🇷 Le système de ciblage géographique pour les communes françaises est prêt !"
    
else
    log_warning "Tests passés : $passed_checks/$total_checks"
    failed=$((total_checks - passed_checks))
    log_error "$failed test(s) échoué(s)"
    echo ""
    echo "🔧 Actions recommandées :"
    echo "  • Vérifiez que Docker est en cours d'exécution"
    echo "  • Redémarrez les services : docker-compose up -d"
    echo "  • Relancez l'import : ./import-fixed.sh"
    echo "  • Consultez les logs : docker logs listmonk_app"
fi

echo ""
echo "📚 Documentation disponible :"
echo "  • INTEGRATION_COMPLETE_FINALE.md : Guide complet"
echo "  • bookmarklet.html : Instructions d'activation"
echo "  • ./check-current-import.sh : Vérification rapide"
echo ""