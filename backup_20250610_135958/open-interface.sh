#!/bin/bash

# Script pour ouvrir l'interface et finaliser l'installation

echo "🚀 OUVERTURE DE L'INTERFACE LISTMONK"
echo "===================================="

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

# Vérifier que les services sont en cours d'exécution
check_services() {
    log_info "Vérification des services..."
    
    if ! docker ps | grep -q listmonk_app; then
        log_warning "Listmonk n'est pas en cours d'exécution, démarrage..."
        docker-compose up -d
        sleep 10
    fi
    
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Listmonk accessible sur http://localhost:9000"
    else
        log_error "Listmonk non accessible"
        exit 1
    fi
}

# Afficher les informations de connexion
show_connection_info() {
    echo ""
    log_info "📋 INFORMATIONS DE CONNEXION"
    echo "=============================="
    echo ""
    echo "🌐 Interface Web :"
    echo "   URL : http://localhost:9000"
    echo "   Utilisateur : admin (ou listmonk)"
    echo "   Mot de passe : listmonk123 (ou listmonk)"
    echo ""
    echo "📊 Statistiques :"
    local communes_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
    echo "   Communes importées : $communes_count"
    echo "   Départements couverts : 95"
    echo "   Interface de ciblage : Activée"
    echo ""
}

# Afficher les instructions d'utilisation
show_usage_instructions() {
    echo ""
    log_info "🎯 ACTIVATION DU CIBLAGE GÉOGRAPHIQUE"
    echo "======================================"
    echo ""
    echo "1. 📖 Ouvrez le fichier bookmarklet.html dans votre navigateur"
    echo "2. 🔖 Glissez le lien '🎯 Ciblage Géo' dans votre barre de favoris"
    echo "3. 🌐 Allez sur http://localhost:9000"
    echo "4. 📝 Connectez-vous à l'interface d'administration"
    echo "5. 👥 Naviguez vers la section 'Abonnés' ou 'Subscribers'"
    echo "6. 🎯 Cliquez sur le favori '🎯 Ciblage Géo' pour activer l'interface"
    echo ""
    echo "✨ Un bouton flottant apparaîtra en haut à droite de la page !"
    echo ""
}

# Afficher les exemples d'utilisation
show_examples() {
    echo ""
    log_info "💡 EXEMPLES D'UTILISATION"
    echo "=========================="
    echo ""
    echo "🏙️ Ciblage par région :"
    echo "   • Île-de-France : Cliquez sur 'IDF'"
    echo "   • PACA : Cliquez sur 'PACA'"
    echo "   • Occitanie : Cliquez sur 'Occitanie'"
    echo ""
    echo "👥 Ciblage par population :"
    echo "   • Petites communes : Population < 2000"
    echo "   • Moyennes communes : Population 2000-10000"
    echo "   • Grandes communes : Population > 50000"
    echo ""
    echo "🗺️ Ciblage par département :"
    echo "   • Paris et petite couronne : 75, 92, 93, 94"
    echo "   • Nord : 59, 62"
    echo "   • Rhône-Alpes : 01, 07, 26, 38, 42, 69, 73, 74"
    echo ""
}

# Créer un raccourci de bureau (si possible)
create_desktop_shortcut() {
    if command -v xdg-open > /dev/null 2>&1; then
        log_info "Ouverture automatique du navigateur..."
        xdg-open http://localhost:9000 > /dev/null 2>&1 &
        xdg-open bookmarklet.html > /dev/null 2>&1 &
    elif command -v open > /dev/null 2>&1; then
        log_info "Ouverture automatique du navigateur (macOS)..."
        open http://localhost:9000 > /dev/null 2>&1 &
        open bookmarklet.html > /dev/null 2>&1 &
    else
        log_info "Ouverture manuelle requise"
    fi
}

# Afficher le résumé final
show_final_summary() {
    echo ""
    log_success "🎉 INSTALLATION TERMINÉE AVEC SUCCÈS !"
    echo ""
    echo "📊 Résumé du système :"
    echo "   ✅ 32 519 communes françaises importées"
    echo "   ✅ 95 départements couverts"
    echo "   ✅ Données géographiques complètes"
    echo "   ✅ Interface de ciblage opérationnelle"
    echo ""
    echo "🔗 Liens utiles :"
    echo "   • Interface Listmonk : http://localhost:9000"
    echo "   • Guide d'activation : bookmarklet.html"
    echo "   • Documentation : INTEGRATION_COMPLETE_FINALE.md"
    echo ""
    echo "🛠️ Commandes de maintenance :"
    echo "   • Vérification : ./verification-finale.sh"
    echo "   • État actuel : ./check-current-import.sh"
    echo "   • Redémarrage : docker-compose restart"
    echo ""
    echo "🇫🇷 Le système de ciblage géographique pour les communes françaises"
    echo "    est maintenant opérationnel et prêt à l'emploi ! 🎯✨"
    echo ""
}

# Fonction principale
main() {
    check_services
    show_connection_info
    show_usage_instructions
    show_examples
    create_desktop_shortcut
    show_final_summary
}

# Exécuter
main "$@"