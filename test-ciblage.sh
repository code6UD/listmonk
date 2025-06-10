#!/bin/bash

# Test rapide du ciblage géographique

echo "🎯 TEST DU CIBLAGE GÉOGRAPHIQUE"
echo "==============================="

# Configuration
API_URL="http://localhost:9000/api"
API_USER="admin"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Détecter le mot de passe
detect_password() {
    local passwords=("listmonk" "changeme")
    
    for pass in "${passwords[@]}"; do
        if curl -s -u "$API_USER:$pass" "$API_URL/health" &>/dev/null; then
            echo "$pass"
            return 0
        fi
    done
    
    return 1
}

# Test d'une requête
test_query() {
    local description="$1"
    local query="$2"
    local password="$3"
    
    # Encoder l'URL
    local encoded_query=$(echo "$query" | sed 's/ /%20/g' | sed 's/=/%3D/g' | sed 's/>/%3E/g' | sed 's/</%3C/g' | sed "s/'/%27/g" | sed 's/"/%22/g' | sed 's/(/%28/g' | sed 's/)/%29/g')
    
    # Faire la requête
    local response=$(curl -s -u "$API_USER:$password" "$API_URL/subscribers?query=$encoded_query&per_page=1")
    local count=$(echo "$response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$count" ]; then
        if [ "$count" -gt 0 ]; then
            log_success "$description : $count résultats"
        else
            log_info "$description : 0 résultat"
        fi
    else
        log_error "$description : Erreur de requête"
        echo "Réponse : $response"
    fi
}

# Fonction principale
main() {
    echo ""
    log_info "Test du ciblage géographique existant"
    echo ""
    
    # Détecter le mot de passe
    local password=$(detect_password)
    if [ -z "$password" ]; then
        log_error "Impossible de se connecter à l'API"
        exit 1
    fi
    
    log_success "Connexion API réussie avec mot de passe : $password"
    echo ""
    
    # Compter le total d'abonnés
    local total_response=$(curl -s -u "$API_USER:$password" "$API_URL/subscribers?per_page=1")
    local total=$(echo "$total_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    log_info "Total d'abonnés : $total"
    echo ""
    
    # Tests de ciblage
    log_info "Tests de ciblage géographique :"
    echo ""
    
    # Test 1 : Abonnés avec département
    test_query "Abonnés avec département" "subscribers.attribs ? 'departement'" "$password"
    
    # Test 2 : Paris (75)
    test_query "Paris (département 75)" "subscribers.attribs->>'departement' = '75'" "$password"
    
    # Test 3 : Marseille (13)
    test_query "Bouches-du-Rhône (13)" "subscribers.attribs->>'departement' = '13'" "$password"
    
    # Test 4 : Rhône (69)
    test_query "Rhône (69)" "subscribers.attribs->>'departement' = '69'" "$password"
    
    # Test 5 : Île-de-France
    test_query "Île-de-France" "subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')" "$password"
    
    # Test 6 : Abonnés avec population
    test_query "Abonnés avec population" "subscribers.attribs ? 'population'" "$password"
    
    # Test 7 : Grandes villes
    test_query "Grandes villes (>50k hab)" "(subscribers.attribs->>'population')::INT > 50000" "$password"
    
    echo ""
    log_info "🎯 Pour utiliser ces requêtes :"
    echo "  1. Aller sur http://localhost:9000"
    echo "  2. Campagnes → Nouvelle campagne"
    echo "  3. Listes → Requête avancée"
    echo "  4. Copier une requête ci-dessus"
    echo ""
    
    # Afficher quelques exemples
    echo "📋 Exemples de requêtes à copier :"
    echo ""
    echo "Paris :"
    echo "subscribers.attribs->>'departement' = '75'"
    echo ""
    echo "Île-de-France :"
    echo "subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')"
    echo ""
    echo "Grandes villes :"
    echo "(subscribers.attribs->>'population')::INT > 50000"
    echo ""
}

# Exécuter
main "$@"