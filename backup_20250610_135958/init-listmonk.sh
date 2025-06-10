#!/bin/bash

# Script d'initialisation de Listmonk

echo "🚀 INITIALISATION DE LISTMONK"
echo "============================="

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

# Vérifier que Listmonk est en cours d'exécution
if ! curl -s http://localhost:9000 > /dev/null 2>&1; then
    log_error "Listmonk n'est pas accessible sur http://localhost:9000"
    log_info "Démarrez les services avec : docker compose up -d"
    exit 1
fi

log_success "Listmonk est accessible"

# Vérifier si déjà initialisé
if curl -s "http://localhost:9000/api/health" | grep -q "invalid session"; then
    log_info "Listmonk nécessite une initialisation"
    
    # Initialiser avec les paramètres par défaut
    log_info "Initialisation en cours..."
    
    # Créer un fichier de configuration temporaire
    cat > /tmp/init_data.json << 'EOF'
{
    "admin_username": "admin",
    "admin_password": "listmonk123",
    "from_email": "noreply@listmonk.app",
    "root_url": "http://localhost:9000"
}
EOF

    # Initialiser via l'API
    init_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/init_data.json \
        "http://localhost:9000/api/admin/init")
    
    if echo "$init_response" | grep -q "success\|already"; then
        log_success "Initialisation réussie"
    else
        log_warning "Réponse d'initialisation : $init_response"
    fi
    
    rm -f /tmp/init_data.json
    
    # Attendre un peu
    sleep 5
else
    log_info "Listmonk déjà initialisé"
fi

# Tester la connexion avec les identifiants admin
log_info "Test de connexion admin..."
auth_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"listmonk123"}' \
    "http://localhost:9000/api/admin/login")

if echo "$auth_response" | grep -q "token"; then
    log_success "Connexion admin réussie"
    
    # Extraire le token
    token=$(echo "$auth_response" | jq -r '.data.token // empty' 2>/dev/null)
    
    if [ -n "$token" ]; then
        log_success "Token obtenu : ${token:0:20}..."
        
        # Tester l'API avec le token
        health_response=$(curl -s -H "Authorization: Bearer $token" "http://localhost:9000/api/health")
        
        if echo "$health_response" | grep -q "success\|ok"; then
            log_success "API accessible avec le token"
            
            # Sauvegarder le token pour les autres scripts
            echo "$token" > .listmonk_token
            
            echo ""
            log_success "🎉 LISTMONK INITIALISÉ AVEC SUCCÈS !"
            echo ""
            echo "📋 Informations de connexion :"
            echo "  • URL : http://localhost:9000"
            echo "  • Utilisateur : admin"
            echo "  • Mot de passe : listmonk123"
            echo "  • Token API sauvegardé dans .listmonk_token"
            echo ""
            log_info "Vous pouvez maintenant importer les communes avec :"
            log_info "./import-all-communes.sh"
            echo ""
            
        else
            log_warning "Problème avec l'API : $health_response"
        fi
    else
        log_error "Impossible d'extraire le token"
    fi
else
    log_error "Échec de connexion admin : $auth_response"
    
    # Essayer avec les identifiants par défaut de Listmonk
    log_info "Tentative avec les identifiants par défaut..."
    default_auth=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"username":"listmonk","password":"listmonk"}' \
        "http://localhost:9000/api/admin/login")
    
    if echo "$default_auth" | grep -q "token"; then
        log_success "Connexion avec identifiants par défaut réussie"
        token=$(echo "$default_auth" | jq -r '.data.token // empty' 2>/dev/null)
        echo "$token" > .listmonk_token
        
        echo ""
        log_success "🎉 LISTMONK ACCESSIBLE !"
        echo ""
        echo "📋 Informations de connexion :"
        echo "  • URL : http://localhost:9000"
        echo "  • Utilisateur : listmonk"
        echo "  • Mot de passe : listmonk"
        echo ""
    else
        log_error "Impossible de se connecter avec les identifiants par défaut"
        log_info "Vérifiez manuellement sur http://localhost:9000"
    fi
fi