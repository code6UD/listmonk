#!/bin/bash

# Script de démarrage rapide pour le système de ciblage géographique

echo "🚀 DÉMARRAGE RAPIDE - CIBLAGE GÉOGRAPHIQUE"
echo "=========================================="

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

# Menu principal
show_menu() {
    echo ""
    echo "🎯 Que souhaitez-vous faire ?"
    echo ""
    echo "1. 🧪 Test rapide (échantillon de 1000 communes)"
    echo "2. 🏛️ Import complet (toutes les 81k communes)"
    echo "3. 🔍 Vérifier l'état actuel"
    echo "4. 🌐 Ouvrir l'interface web"
    echo "5. 🔧 Diagnostic et réparation"
    echo "6. 📊 Vérification finale du système"
    echo "7. 🚀 Mise à jour automatisée"
    echo "8. 📚 Afficher la documentation"
    echo "9. ❌ Quitter"
    echo ""
    read -p "Votre choix (1-9) : " choice
}

# Test rapide
run_test() {
    log_info "Lancement du test rapide..."
    if [ -f "test-import-sample.sh" ]; then
        ./test-import-sample.sh
    else
        log_error "Script de test non trouvé"
    fi
}

# Import complet
run_import() {
    echo ""
    log_warning "⚠️  ATTENTION : L'import complet peut prendre 30-60 minutes"
    log_info "Il va importer ~81 000 communes françaises"
    echo ""
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Lancement de l'import complet..."
        if [ -f "import-all-communes.sh" ]; then
            ./import-all-communes.sh
        else
            log_error "Script d'import non trouvé"
        fi
    else
        log_info "Import annulé"
    fi
}

# Vérifier l'état
check_status() {
    log_info "Vérification de l'état actuel..."
    if [ -f "check-current-import.sh" ]; then
        ./check-current-import.sh
    else
        log_error "Script de vérification non trouvé"
    fi
}

# Ouvrir l'interface web
open_web() {
    log_info "Vérification de l'interface web..."
    
    # Vérifier si les services sont démarrés
    if ! docker ps | grep -q "listmonk_mairies"; then
        log_warning "Services non démarrés, démarrage..."
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            log_info "Attente du démarrage (30 secondes)..."
            sleep 30
        else
            log_error "Configuration Docker non trouvée"
            return 1
        fi
    fi
    
    # Vérifier l'accessibilité
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Interface web accessible !"
        echo ""
        echo "🌐 Ouvrez votre navigateur sur : http://localhost:9000"
        echo "👤 Utilisateur : api"
        echo "🔑 Mot de passe : RmAp4lu4hiMSE9GCV2KOSpjLWH0k7h1o"
        echo ""
        echo "🎯 Pour le ciblage géographique :"
        echo "  1. Allez dans 'Abonnés'"
        echo "  2. Cliquez sur le bouton '🎯 Ciblage Géo'"
        echo "  3. Sélectionnez vos critères"
        echo "  4. Cliquez 'Appliquer'"
    else
        log_error "Interface web non accessible"
        log_info "Essayez de redémarrer les services : docker compose restart"
    fi
}

# Diagnostic
run_diagnostic() {
    log_info "Lancement du diagnostic..."
    if [ -f "diagnose-and-fix.sh" ]; then
        ./diagnose-and-fix.sh
    else
        log_error "Script de diagnostic non trouvé"
    fi
}

# Vérification finale
run_verification() {
    log_info "Vérification finale du système..."
    if [ -f "final-verification.sh" ]; then
        ./final-verification.sh
    else
        log_error "Script de vérification finale non trouvé"
    fi
}

# Mise à jour
run_update() {
    log_info "Lancement de la mise à jour automatisée..."
    if [ -f "auto-update-deploy.sh" ]; then
        ./auto-update-deploy.sh
    else
        log_error "Script de mise à jour non trouvé"
    fi
}

# Documentation
show_docs() {
    echo ""
    log_info "📚 Documentation disponible :"
    echo ""
    echo "📖 Guides principaux :"
    echo "  • README_CIBLAGE_GEOGRAPHIQUE.md - Guide complet d'utilisation"
    echo "  • PROJECT_SUMMARY.md - Vue d'ensemble du projet"
    echo "  • TECHNICAL_SUMMARY.md - Documentation technique"
    echo "  • UPDATE_SUMMARY.md - Résumé des dernières mises à jour"
    echo ""
    echo "🔧 Scripts disponibles :"
    echo "  • ./test-import-sample.sh - Test avec échantillon"
    echo "  • ./import-all-communes.sh - Import complet"
    echo "  • ./check-current-import.sh - Vérification de l'état"
    echo "  • ./auto-update-deploy.sh - Mise à jour automatisée"
    echo "  • ./final-verification.sh - Vérification finale"
    echo ""
    echo "🌐 Interface web :"
    echo "  • URL : http://localhost:9000"
    echo "  • Utilisateur : api"
    echo "  • Mot de passe : RmAp4lu4hiMSE9GCV2KOSpjLWH0k7h1o"
    echo ""
    echo "🎯 Fonctionnalités :"
    echo "  • Ciblage par département (75, 13, 69, etc.)"
    echo "  • Ciblage par population (min/max habitants)"
    echo "  • Filtres rapides (IDF, PACA, grandes villes, etc.)"
    echo "  • ~81 000 communes françaises disponibles"
    echo ""
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# Boucle principale
main() {
    while true; do
        show_menu
        
        case $choice in
            1)
                run_test
                ;;
            2)
                run_import
                ;;
            3)
                check_status
                ;;
            4)
                open_web
                ;;
            5)
                run_diagnostic
                ;;
            6)
                run_verification
                ;;
            7)
                run_update
                ;;
            8)
                show_docs
                ;;
            9)
                echo ""
                log_success "Au revoir ! 👋"
                echo ""
                echo "🔗 Liens utiles :"
                echo "  • Dépôt : https://github.com/code6UD/listmonk"
                echo "  • Interface : http://localhost:9000"
                echo "  • Documentation : README_CIBLAGE_GEOGRAPHIQUE.md"
                echo ""
                exit 0
                ;;
            *)
                log_error "Choix invalide. Veuillez choisir entre 1 et 9."
                ;;
        esac
        
        echo ""
        read -p "Appuyez sur Entrée pour revenir au menu..."
    done
}

# Vérification initiale
echo ""
log_info "Vérification de l'environnement..."

if [ ! -f "mairielist.csv" ]; then
    log_error "Fichier CSV principal manquant (mairielist.csv)"
    echo "Assurez-vous d'être dans le bon répertoire."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    log_warning "Docker n'est pas installé"
    log_info "Exécutez d'abord : ./auto-update-deploy.sh"
fi

log_success "Environnement vérifié"

# Afficher le statut actuel
echo ""
log_info "📊 Statut actuel :"
csv_lines=$(wc -l < mairielist.csv)
echo "  • Fichier CSV : $csv_lines lignes"

if docker ps | grep -q "listmonk_mairies"; then
    echo "  • Services : ✅ Démarrés"
    if docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;" &>/dev/null; then
        count=$(docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
        echo "  • Communes importées : $count"
    fi
else
    echo "  • Services : ⚠️  Non démarrés"
fi

if curl -s http://localhost:9000 &>/dev/null; then
    echo "  • Interface web : ✅ Accessible"
else
    echo "  • Interface web : ⚠️  Non accessible"
fi

# Lancer le menu
main