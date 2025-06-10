#!/bin/bash

# Script d'analyse du fichier CSV pour comprendre les données manquantes

echo "🔍 ANALYSE DU FICHIER CSV"
echo "========================="

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

# Analyser le fichier CSV original
analyze_csv() {
    log_info "Analyse du fichier mairielist.csv..."
    
    local total_lines=$(wc -l < mairielist.csv)
    log_info "Total lignes dans le fichier : $total_lines"
    
    # Compter les lignes avec email
    local with_email=$(awk -F',' 'NR>1 && $1 != "" && $1 != "nan" && $1 ~ /@/ {count++} END {print count+0}' mairielist.csv)
    log_info "Lignes avec email valide : $with_email"
    
    # Compter les emails uniques
    local unique_emails=$(awk -F',' 'NR>1 && $1 != "" && $1 != "nan" && $1 ~ /@/ {print $1}' mairielist.csv | sort | uniq | wc -l)
    log_info "Emails uniques : $unique_emails"
    
    # Différence
    local duplicates=$((with_email - unique_emails))
    log_warning "Emails en doublon : $duplicates"
    
    echo ""
    log_info "📊 Répartition des données :"
    echo "  • Total lignes : $total_lines"
    echo "  • Avec email valide : $with_email"
    echo "  • Emails uniques : $unique_emails"
    echo "  • Doublons : $duplicates"
    echo ""
    
    # Analyser les doublons
    if [ "$duplicates" -gt 0 ]; then
        log_warning "Analyse des doublons les plus fréquents :"
        awk -F',' 'NR>1 && $1 != "" && $1 != "nan" && $1 ~ /@/ {print $1}' mairielist.csv | sort | uniq -c | sort -nr | head -10 | while read count email; do
            echo "    $email : $count occurrences"
        done
    fi
}

# Analyser les données manquantes
analyze_missing_data() {
    log_info "Analyse des données manquantes..."
    
    # Créer un script Python pour une analyse détaillée
    cat > analyze_data.py << 'EOF'
import csv
import json

def analyze_csv():
    total_lines = 0
    valid_emails = 0
    unique_emails = set()
    missing_fields = {
        'email': 0,
        'nom_commune': 0,
        'departement_numero': 0,
        'population_commune': 0,
        'code_insee': 0
    }
    
    with open('mairielist.csv', 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            total_lines += 1
            
            email = row.get('email', '').strip()
            
            # Analyser les champs manquants
            for field in missing_fields:
                value = row.get(field, '').strip()
                if not value or value.lower() in ['nan', 'null', '']:
                    missing_fields[field] += 1
            
            # Analyser les emails
            if email and '@' in email and email.lower() not in ['nan', 'null']:
                valid_emails += 1
                unique_emails.add(email.lower())
    
    print(f"Total lignes analysées : {total_lines}")
    print(f"Emails valides : {valid_emails}")
    print(f"Emails uniques : {len(unique_emails)}")
    print(f"Doublons d'emails : {valid_emails - len(unique_emails)}")
    print()
    print("Champs manquants :")
    for field, count in missing_fields.items():
        percentage = (count / total_lines) * 100 if total_lines > 0 else 0
        print(f"  • {field}: {count} ({percentage:.1f}%)")
    
    return len(unique_emails)

if __name__ == "__main__":
    analyze_csv()
EOF

    python3 analyze_data.py
    rm -f analyze_data.py
}

# Comparer avec la base de données
compare_with_db() {
    log_info "Comparaison avec la base de données..."
    
    local db_count=$(docker exec listmonk_db psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" | tr -d ' ')
    log_info "Communes dans la base de données : $db_count"
    
    # Analyser les emails uniques dans le CSV
    local csv_unique=$(awk -F',' 'NR>1 && $1 != "" && $1 != "nan" && $1 ~ /@/ {print tolower($1)}' mairielist.csv | sort | uniq | wc -l)
    log_info "Emails uniques dans le CSV : $csv_unique"
    
    local difference=$((csv_unique - db_count))
    
    if [ "$difference" -gt 0 ]; then
        log_warning "Il manque $difference communes dans la base de données"
        log_info "Cela peut être dû à :"
        echo "  • Des erreurs lors de l'import"
        echo "  • Des emails invalides"
        echo "  • Des contraintes de base de données"
    else
        log_success "Toutes les communes uniques ont été importées"
    fi
}

# Proposer des solutions
propose_solutions() {
    echo ""
    log_info "💡 Solutions pour améliorer l'import :"
    echo ""
    echo "1. 🧹 Nettoyer les doublons avant import :"
    echo "   ./create-unique-csv.sh"
    echo ""
    echo "2. 🔄 Réimporter avec gestion des doublons :"
    echo "   ./import-with-dedup.sh"
    echo ""
    echo "3. 📊 Analyser les erreurs d'import :"
    echo "   ./analyze-import-errors.sh"
    echo ""
    echo "4. ✅ Vérifier l'interface de ciblage :"
    echo "   http://localhost:9000"
    echo ""
}

# Fonction principale
main() {
    echo ""
    analyze_csv
    echo ""
    analyze_missing_data
    echo ""
    compare_with_db
    propose_solutions
}

# Exécuter
main "$@"