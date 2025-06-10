#!/bin/bash

# Script de vérification finale du système complet

echo "🔍 VÉRIFICATION FINALE DU SYSTÈME"
echo "================================="

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

# Score de santé du système
health_score=0
max_score=0

check_item() {
    local description="$1"
    local command="$2"
    local weight="${3:-1}"
    
    max_score=$((max_score + weight))
    
    if eval "$command" &>/dev/null; then
        log_success "$description"
        health_score=$((health_score + weight))
        return 0
    else
        log_error "$description"
        return 1
    fi
}

check_warning() {
    local description="$1"
    local command="$2"
    local weight="${3:-1}"
    
    max_score=$((max_score + weight))
    
    if eval "$command" &>/dev/null; then
        log_success "$description"
        health_score=$((health_score + weight))
        return 0
    else
        log_warning "$description"
        return 1
    fi
}

echo ""
log_info "🔧 Vérification des outils et dépendances"
echo "----------------------------------------"

check_item "Git installé" "command -v git"
check_item "Docker installé" "command -v docker"
check_item "Docker Compose installé" "docker compose version"
check_item "Python3 installé" "command -v python3"
check_item "jq installé" "command -v jq"

echo ""
log_info "📁 Vérification des fichiers essentiels"
echo "---------------------------------------"

check_item "Fichier CSV principal (mairielist.csv)" "[ -f mairielist.csv ]" 3
check_item "Script d'import complet" "[ -f import-all-communes.sh ] && [ -x import-all-communes.sh ]" 2
check_item "Script de vérification" "[ -f check-current-import.sh ] && [ -x check-current-import.sh ]" 2
check_item "Script de test" "[ -f test-import-sample.sh ] && [ -x test-import-sample.sh ]" 2
check_item "Script de mise à jour auto" "[ -f auto-update-deploy.sh ] && [ -x auto-update-deploy.sh ]" 2
check_item "Configuration Docker" "[ -f docker-compose.yml ]" 2

echo ""
log_info "📊 Vérification de la qualité des données"
echo "-----------------------------------------"

if [ -f "mairielist.csv" ]; then
    csv_lines=$(wc -l < mairielist.csv)
    if [ "$csv_lines" -gt 80000 ]; then
        log_success "Fichier CSV complet ($csv_lines lignes)"
        health_score=$((health_score + 3))
    elif [ "$csv_lines" -gt 40000 ]; then
        log_warning "Fichier CSV partiel ($csv_lines lignes)"
        health_score=$((health_score + 2))
    else
        log_error "Fichier CSV incomplet ($csv_lines lignes)"
    fi
    max_score=$((max_score + 3))
    
    # Vérifier l'en-tête
    header=$(head -1 mairielist.csv)
    if [[ "$header" == *"email"* ]] && [[ "$header" == *"nom_commune"* ]]; then
        log_success "Format CSV valide"
        health_score=$((health_score + 1))
    else
        log_error "Format CSV invalide"
    fi
    max_score=$((max_score + 1))
else
    log_error "Fichier CSV principal manquant"
    max_score=$((max_score + 4))
fi

echo ""
log_info "🐳 Vérification de l'environnement Docker"
echo "-----------------------------------------"

check_warning "Docker en cours d'exécution" "docker ps"
check_warning "Images Docker disponibles" "docker images | grep -E '(postgres|listmonk)'"

if docker ps | grep -q "listmonk_mairies_db"; then
    log_success "Base de données en cours d'exécution"
    health_score=$((health_score + 2))
    
    # Vérifier les données
    if docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;" &>/dev/null; then
        count=$(docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
        if [ "$count" -gt 70000 ]; then
            log_success "Import complet détecté ($count communes)"
            health_score=$((health_score + 3))
        elif [ "$count" -gt 10000 ]; then
            log_warning "Import partiel détecté ($count communes)"
            health_score=$((health_score + 2))
        elif [ "$count" -gt 0 ]; then
            log_warning "Import minimal détecté ($count communes)"
            health_score=$((health_score + 1))
        else
            log_error "Aucune donnée importée"
        fi
    else
        log_warning "Impossible de vérifier les données"
    fi
else
    log_warning "Base de données non démarrée"
fi
max_score=$((max_score + 5))

if docker ps | grep -q "listmonk_mairies"; then
    log_success "Listmonk en cours d'exécution"
    health_score=$((health_score + 2))
    
    # Vérifier l'API
    if curl -s http://localhost:9000 &>/dev/null; then
        log_success "Interface web accessible"
        health_score=$((health_score + 2))
    else
        log_warning "Interface web non accessible"
        health_score=$((health_score + 1))
    fi
else
    log_warning "Listmonk non démarré"
fi
max_score=$((max_score + 4))

echo ""
log_info "🧪 Tests fonctionnels"
echo "--------------------"

# Test de conversion Python
cat > test_functionality.py << 'EOF'
import csv
import json
import sys

def test_csv_processing():
    try:
        # Test avec les premières lignes du CSV
        with open('mairielist.csv', 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            count = 0
            for i, row in enumerate(reader):
                if i >= 5:  # Tester seulement 5 lignes
                    break
                email = row.get('email', '').strip()
                if email and '@' in email:
                    # Test de création d'attributs JSON
                    attribs = {
                        'nom_commune': row.get('nom_commune', ''),
                        'departement_numero': row.get('departement_numero', ''),
                        'population_commune': row.get('population_commune', '')
                    }
                    json.dumps(attribs)  # Test de sérialisation JSON
                    count += 1
            return count > 0
    except Exception as e:
        print(f"Erreur: {e}")
        return False

if __name__ == "__main__":
    if test_csv_processing():
        print("Test de traitement CSV réussi")
        sys.exit(0)
    else:
        print("Test de traitement CSV échoué")
        sys.exit(1)
EOF

if python3 test_functionality.py; then
    log_success "Test de traitement CSV"
    health_score=$((health_score + 2))
else
    log_error "Test de traitement CSV échoué"
fi
max_score=$((max_score + 2))

# Nettoyer
rm -f test_functionality.py

echo ""
log_info "📚 Vérification de la documentation"
echo "----------------------------------"

check_warning "README principal" "[ -f README.md ]"
check_warning "Guide de ciblage géographique" "[ -f README_CIBLAGE_GEOGRAPHIQUE.md ]"
check_warning "Résumé du projet" "[ -f PROJECT_SUMMARY.md ]"
check_warning "Documentation technique" "[ -f TECHNICAL_SUMMARY.md ]"

echo ""
log_info "🎯 Recommandations d'utilisation"
echo "--------------------------------"

echo "📋 Scripts disponibles :"
echo "  • ./check-current-import.sh - Vérifier l'état actuel"
echo "  • ./test-import-sample.sh - Test avec échantillon"
echo "  • ./import-all-communes.sh - Import complet (81k communes)"
echo "  • ./auto-update-deploy.sh - Mise à jour automatisée"
echo "  • ./verify-geo-targeting.sh - Vérification complète"

echo ""
echo "🚀 Démarrage rapide :"
echo "  1. Test : ./test-import-sample.sh"
echo "  2. Import : ./import-all-communes.sh"
echo "  3. Interface : http://localhost:9000"

echo ""
echo "🔧 Maintenance :"
echo "  • Diagnostic : ./diagnose-and-fix.sh"
echo "  • Mise à jour : ./auto-update-deploy.sh"
echo "  • Vérification : ./final-verification.sh"

echo ""
log_info "📊 SCORE DE SANTÉ DU SYSTÈME"
echo "============================"

percentage=$((health_score * 100 / max_score))

if [ "$percentage" -ge 90 ]; then
    log_success "Score : $health_score/$max_score ($percentage%) - EXCELLENT ✨"
    echo "🎉 Le système est prêt pour la production !"
elif [ "$percentage" -ge 75 ]; then
    log_success "Score : $health_score/$max_score ($percentage%) - BON ✅"
    echo "👍 Le système fonctionne bien, quelques améliorations possibles"
elif [ "$percentage" -ge 50 ]; then
    log_warning "Score : $health_score/$max_score ($percentage%) - MOYEN ⚠️"
    echo "🔧 Le système nécessite quelques corrections"
else
    log_error "Score : $health_score/$max_score ($percentage%) - FAIBLE ❌"
    echo "🚨 Le système nécessite des corrections importantes"
fi

echo ""
if [ "$percentage" -lt 75 ]; then
    log_info "💡 Pour améliorer le score :"
    echo "  • Exécutez : ./auto-update-deploy.sh"
    echo "  • Démarrez Docker : docker compose up -d"
    echo "  • Lancez l'import : ./import-all-communes.sh"
fi

echo ""
log_info "🔗 Liens utiles :"
echo "  • Dépôt GitHub : https://github.com/code6UD/listmonk"
echo "  • Interface web : http://localhost:9000"
echo "  • Documentation : README_CIBLAGE_GEOGRAPHIQUE.md"

echo ""