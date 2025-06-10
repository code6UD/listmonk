#!/bin/bash

# Script de vérification simplifié

echo "🔍 VÉRIFICATION SYSTÈME SIMPLIFIÉE"
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

echo ""
log_info "🐳 Vérification des conteneurs Docker"

# Vérifier les conteneurs
if docker ps | grep -q listmonk_app; then
    log_success "Application Listmonk en cours d'exécution"
else
    log_error "Application Listmonk non trouvée"
fi

if docker ps | grep -q listmonk_db; then
    log_success "Base de données PostgreSQL en cours d'exécution"
else
    log_error "Base de données PostgreSQL non trouvée"
fi

echo ""
log_info "🌐 Vérification de l'accès réseau"

# Vérifier l'accès web
if curl -s http://localhost:9000 > /dev/null 2>&1; then
    log_success "Interface web accessible sur http://localhost:9000"
else
    log_error "Interface web non accessible"
fi

echo ""
log_info "🗄️ Vérification des données"

# Vérifier la base de données
if docker exec listmonk_db psql -U listmonk -d listmonk -c "SELECT 1;" > /dev/null 2>&1; then
    log_success "Connexion à la base de données établie"
    
    # Compter les communes
    communes_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    if [ -n "$communes_count" ] && [ "$communes_count" -gt 0 ]; then
        log_success "Communes importées : $communes_count"
    else
        log_error "Aucune commune trouvée"
    fi
    
    # Vérifier les données géographiques
    with_dept=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE department_code IS NOT NULL;" 2>/dev/null | tr -d ' ')
    if [ -n "$with_dept" ] && [ "$with_dept" -gt 0 ]; then
        log_success "Communes avec département : $with_dept"
    else
        log_warning "Données de département manquantes"
    fi
    
    with_pop=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers WHERE population IS NOT NULL;" 2>/dev/null | tr -d ' ')
    if [ -n "$with_pop" ] && [ "$with_pop" -gt 0 ]; then
        log_success "Communes avec population : $with_pop"
    else
        log_warning "Données de population manquantes"
    fi
    
else
    log_error "Impossible de se connecter à la base de données"
fi

echo ""
log_info "📁 Vérification des fichiers"

# Vérifier les fichiers importants
files_to_check=(
    "mairielist.csv:Fichier source CSV"
    "geo-targeting.js:Script de ciblage géographique"
    "bookmarklet.html:Bookmarklet d'activation"
    "INTEGRATION_COMPLETE_FINALE.md:Documentation finale"
    "README_FINAL.md:Guide utilisateur"
)

for file_info in "${files_to_check[@]}"; do
    file=$(echo "$file_info" | cut -d: -f1)
    desc=$(echo "$file_info" | cut -d: -f2)
    
    if [ -f "$file" ]; then
        log_success "$desc présent"
    else
        log_warning "$desc manquant"
    fi
done

echo ""
log_info "🎯 Vérification de l'interface de ciblage"

# Vérifier le script de ciblage
if curl -s http://localhost:9000/public/geo-targeting.js > /dev/null 2>&1; then
    log_success "Script de ciblage accessible via HTTP"
elif [ -f "geo-targeting.js" ]; then
    log_warning "Script de ciblage créé (activation manuelle requise)"
else
    log_error "Script de ciblage non trouvé"
fi

echo ""
log_info "📊 Statistiques du système"

if [ -n "$communes_count" ] && [ "$communes_count" -gt 0 ]; then
    echo "  • Total communes : $communes_count"
    echo "  • Avec département : ${with_dept:-0}"
    echo "  • Avec population : ${with_pop:-0}"
    
    # Quelques exemples
    echo ""
    log_info "🏙️ Échantillon des communes (top 5 par population)"
    docker exec listmonk_db psql -U listmonk -d listmonk -t -c "
    SELECT 
        name || ' (' || COALESCE(department_code, '?') || ') : ' || COALESCE(population::text, 'N/A') || ' hab'
    FROM subscribers 
    WHERE population IS NOT NULL
    ORDER BY population DESC
    LIMIT 5;" 2>/dev/null | while read line; do
        if [ -n "$line" ]; then
            echo "    $line"
        fi
    done
fi

echo ""
echo "🎉 RÉSUMÉ"
echo "========="

if [ -n "$communes_count" ] && [ "$communes_count" -gt 30000 ]; then
    log_success "Système opérationnel ! $communes_count communes disponibles"
    echo ""
    echo "🚀 Prochaines étapes :"
    echo "  1. Ouvrez http://localhost:9000 dans votre navigateur"
    echo "  2. Consultez bookmarklet.html pour activer le ciblage géographique"
    echo "  3. Lisez README_FINAL.md pour le guide complet"
    echo ""
    echo "🎯 Le système de ciblage géographique est prêt à l'emploi !"
else
    log_warning "Système partiellement opérationnel"
    echo ""
    echo "🔧 Actions recommandées :"
    echo "  • Redémarrer les services : docker-compose restart"
    echo "  • Réimporter les données : ./import-fixed.sh"
    echo "  • Consulter les logs : docker logs listmonk_app"
fi

echo ""