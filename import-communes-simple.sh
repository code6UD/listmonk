#!/bin/bash

# Import simple des communes françaises pour Listmonk
# Utilise l'API native et les attributs JSON

echo "🏛️ IMPORT SIMPLE DES COMMUNES FRANÇAISES"
echo "========================================"

# Configuration
API_URL="http://localhost:9000/api"
API_USER="admin"
API_PASS="changeme"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier que Listmonk est accessible
    if ! curl -s "$API_URL/health" &>/dev/null; then
        log_error "Listmonk non accessible sur $API_URL"
        log_info "Vérifiez que les services sont démarrés :"
        log_info "docker-compose -f docker-compose.mairies.yml up -d"
        exit 1
    fi
    
    # Vérifier l'authentification
    if ! curl -s -u "$API_USER:$API_PASS" "$API_URL/lists" &>/dev/null; then
        log_error "Authentification échouée"
        log_info "Vérifiez les identifiants : $API_USER / $API_PASS"
        exit 1
    fi
    
    # Vérifier le fichier CSV
    if [ ! -f "mairielist.csv" ]; then
        log_error "Fichier mairielist.csv non trouvé"
        exit 1
    fi
    
    local csv_lines=$(wc -l < mairielist.csv)
    log_success "Prérequis OK - CSV avec $csv_lines lignes"
}

# Créer ou récupérer la liste
setup_list() {
    log_info "Configuration de la liste..."
    
    # Vérifier si une liste existe déjà
    local lists_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/lists")
    local list_id=$(echo "$lists_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ -n "$list_id" ]; then
        log_info "Utilisation de la liste existante (ID: $list_id)"
        echo "$list_id"
        return
    fi
    
    # Créer une nouvelle liste
    log_info "Création d'une nouvelle liste..."
    local create_response=$(curl -s -u "$API_USER:$API_PASS" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Communes France",
            "type": "public",
            "optin": "single",
            "tags": ["communes", "france", "mairies"]
        }' \
        "$API_URL/lists")
    
    list_id=$(echo "$create_response" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$list_id" ]; then
        log_success "Liste créée (ID: $list_id)"
        echo "$list_id"
    else
        log_error "Échec de création de la liste"
        echo "$create_response"
        exit 1
    fi
}

# Préparer le CSV pour l'import
prepare_csv() {
    log_info "Préparation du CSV pour l'import..."
    
    python3 << 'EOF'
import csv
import json
import re

def clean_value(value):
    """Nettoie une valeur CSV"""
    if not value or value.lower() in ['nan', 'null', '', 'none']:
        return None
    return str(value).strip()

def extract_department(value):
    """Extrait le numéro de département"""
    if not value:
        return None
    
    # Nettoyer et extraire les chiffres
    dept = re.sub(r'[^0-9]', '', str(value))
    
    # Gérer les cas spéciaux
    if len(dept) >= 2:
        return dept[:2]
    elif len(dept) == 1:
        return f"0{dept}"
    
    return None

def prepare_import_csv():
    input_file = 'mairielist.csv'
    output_file = 'communes-import.csv'
    
    with open(input_file, 'r', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        
        with open(output_file, 'w', encoding='utf-8', newline='') as outfile:
            fieldnames = ['email', 'name', 'attribs']
            writer = csv.DictWriter(outfile, fieldnames=fieldnames)
            writer.writeheader()
            
            processed = 0
            valid = 0
            
            for row in reader:
                processed += 1
                
                # Extraire les données de base
                email = clean_value(row.get('email'))
                nom_commune = clean_value(row.get('nom_commune'))
                
                # Vérifier l'email
                if not email or '@' not in email:
                    continue
                
                # Extraire les attributs géographiques
                departement = extract_department(row.get('departement_numero') or row.get('departement'))
                population = clean_value(row.get('population_commune') or row.get('population'))
                code_insee = clean_value(row.get('code_insee'))
                zipcode = clean_value(row.get('zipcode') or row.get('code_postal'))
                
                # Créer les attributs JSON
                attribs = {}
                
                if nom_commune:
                    attribs['commune'] = nom_commune
                
                if departement:
                    attribs['departement'] = departement
                
                if population and population.isdigit():
                    attribs['population'] = int(population)
                
                if code_insee:
                    attribs['code_insee'] = code_insee
                
                if zipcode:
                    attribs['code_postal'] = zipcode
                
                # Ajouter des métadonnées
                attribs['type'] = 'mairie'
                attribs['pays'] = 'France'
                
                # Écrire la ligne
                writer.writerow({
                    'email': email,
                    'name': nom_commune or f"Mairie {email.split('@')[0]}",
                    'attribs': json.dumps(attribs, ensure_ascii=False)
                })
                
                valid += 1
            
            print(f"Traitement terminé : {valid}/{processed} communes valides")

if __name__ == "__main__":
    prepare_import_csv()
EOF
    
    if [ -f "communes-import.csv" ]; then
        local import_lines=$(wc -l < communes-import.csv)
        log_success "CSV préparé : $((import_lines - 1)) communes"
    else
        log_error "Échec de préparation du CSV"
        exit 1
    fi
}

# Lancer l'import via l'API
import_subscribers() {
    local list_id=$1
    
    log_info "Lancement de l'import..."
    
    # Préparer les paramètres d'import
    local import_params=$(cat << EOF
{
    "list_ids": [$list_id],
    "overwrite": true,
    "delim": ",",
    "mode": "subscribe"
}
EOF
)
    
    # Lancer l'import
    local import_response=$(curl -s -u "$API_USER:$API_PASS" \
        -F "file=@communes-import.csv" \
        -F "params=$import_params" \
        "$API_URL/import/subscribers")
    
    # Vérifier la réponse
    if echo "$import_response" | grep -q '"status":"running"'; then
        log_success "Import lancé avec succès"
        
        # Attendre la fin de l'import
        log_info "Attente de la fin de l'import (60 secondes)..."
        sleep 60
        
        # Vérifier le résultat
        check_import_result
    else
        log_error "Échec du lancement de l'import"
        echo "$import_response"
        exit 1
    fi
}

# Vérifier le résultat de l'import
check_import_result() {
    log_info "Vérification du résultat..."
    
    # Compter les abonnés
    local subscribers_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/subscribers?per_page=1")
    local total=$(echo "$subscribers_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$total" ] && [ "$total" -gt 0 ]; then
        log_success "Import réussi : $total communes importées"
        
        # Vérifier quelques exemples
        log_info "Vérification des attributs..."
        
        # Test département 75 (Paris)
        local paris_query="subscribers.attribs->>'departement' = '75'"
        local paris_count=$(curl -s -u "$API_USER:$API_PASS" \
            "$API_URL/subscribers?query=$(echo "$paris_query" | sed 's/ /%20/g')" | \
            grep -o '"total":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$paris_count" ] && [ "$paris_count" -gt 0 ]; then
            log_success "Ciblage géographique fonctionnel : $paris_count communes à Paris"
        else
            log_warning "Ciblage géographique à vérifier"
        fi
        
    else
        log_error "Aucune commune importée"
        exit 1
    fi
}

# Créer des exemples de requêtes
create_query_examples() {
    log_info "Création des exemples de requêtes..."
    
    cat > exemples-requetes.md << 'EOF'
# 🎯 Exemples de Requêtes de Ciblage Géographique

## Ciblage par Département

### Paris
```sql
subscribers.attribs->>'departement' = '75'
```

### Bouches-du-Rhône (Marseille)
```sql
subscribers.attribs->>'departement' = '13'
```

### Île-de-France
```sql
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')
```

### PACA
```sql
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84')
```

## Ciblage par Population

### Grandes villes (>100k habitants)
```sql
(subscribers.attribs->>'population')::INT > 100000
```

### Villes moyennes (10k-100k habitants)
```sql
(subscribers.attribs->>'population')::INT BETWEEN 10000 AND 100000
```

### Petites communes (<2k habitants)
```sql
(subscribers.attribs->>'population')::INT < 2000
```

## Ciblage Combiné

### Grandes villes d'Île-de-France
```sql
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')
AND (subscribers.attribs->>'population')::INT > 50000
```

### Petites communes PACA
```sql
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84')
AND (subscribers.attribs->>'population')::INT < 5000
```

## Utilisation

1. Aller dans Listmonk → Campagnes → Nouvelle campagne
2. Dans le champ "Listes", cliquer sur "Requête avancée"
3. Copier-coller une des requêtes ci-dessus
4. Cliquer sur "Aperçu" pour voir le nombre de destinataires

## Interface Web

Accédez à http://localhost:9000 pour utiliser ces requêtes.
EOF
    
    log_success "Exemples créés dans exemples-requetes.md"
}

# Nettoyer les fichiers temporaires
cleanup() {
    log_info "Nettoyage..."
    rm -f communes-import.csv
}

# Fonction principale
main() {
    echo ""
    log_info "Import simple des communes françaises pour Listmonk"
    echo ""
    
    # Vérifications
    check_prerequisites
    
    # Configuration
    local list_id=$(setup_list)
    
    # Import
    prepare_csv
    import_subscribers "$list_id"
    
    # Finalisation
    create_query_examples
    cleanup
    
    echo ""
    log_success "🎉 Import terminé avec succès !"
    echo ""
    echo "🌐 Interface Listmonk : http://localhost:9000"
    echo "📋 Exemples de requêtes : exemples-requetes.md"
    echo ""
    echo "🎯 Pour créer une campagne ciblée :"
    echo "  1. Aller dans Campagnes → Nouvelle campagne"
    echo "  2. Cliquer sur 'Requête avancée' dans Listes"
    echo "  3. Utiliser une requête des exemples"
    echo ""
}

# Exécuter
main "$@"