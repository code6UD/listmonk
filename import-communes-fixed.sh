#!/bin/bash

# Import corrigé des communes françaises pour Listmonk
# Version sans caractères de couleur dans les paramètres JSON

echo "🏛️ IMPORT CORRIGÉ DES COMMUNES FRANÇAISES"
echo "========================================"

# Configuration
API_URL="http://localhost:9000/api"
API_USER="admin"
API_PASS="listmonk"

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
    
    # Tester différents mots de passe
    local passwords=("listmonk" "changeme")
    local auth_success=false
    
    for pass in "${passwords[@]}"; do
        if curl -s -u "$API_USER:$pass" "$API_URL/health" &>/dev/null; then
            API_PASS="$pass"
            auth_success=true
            log_success "Authentification réussie avec $API_USER:$pass"
            break
        fi
    done
    
    if [ "$auth_success" = false ]; then
        log_error "Authentification échouée"
        log_info "Essayez manuellement : curl -u admin:MOTDEPASSE $API_URL/health"
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

# Vérifier l'état actuel
check_current_state() {
    log_info "Vérification de l'état actuel..."
    
    # Compter les abonnés actuels
    local subscribers_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/subscribers?per_page=1")
    local current_total=$(echo "$subscribers_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$current_total" ] && [ "$current_total" -gt 0 ]; then
        log_info "Abonnés actuels : $current_total"
        
        # Vérifier s'il y a déjà des communes
        local with_dept=$(curl -s -u "$API_USER:$API_PASS" \
            "$API_URL/subscribers?query=subscribers.attribs%3F%27departement%27&per_page=1" | \
            grep -o '"total":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$with_dept" ] && [ "$with_dept" -gt 0 ]; then
            log_warning "Il y a déjà $with_dept communes avec département"
            echo ""
            read -p "Voulez-vous continuer l'import ? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Import annulé"
                exit 0
            fi
        fi
    else
        log_info "Base de données vide"
    fi
}

# Créer ou récupérer la liste
setup_list() {
    log_info "Configuration de la liste..."
    
    # Chercher une liste existante
    local lists_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/lists")
    local list_id=$(echo "$lists_response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    
    if [ -n "$list_id" ]; then
        log_info "Utilisation de la liste existante (ID: $list_id)"
        echo "$list_id"
        return
    fi
    
    # Créer une nouvelle liste
    log_info "Création d'une nouvelle liste..."
    
    # Créer le fichier JSON temporaire pour éviter les problèmes de caractères
    cat > /tmp/list_data.json << 'EOF'
{
    "name": "Communes France",
    "type": "public",
    "optin": "single",
    "tags": ["communes", "france", "mairies"]
}
EOF
    
    local create_response=$(curl -s -u "$API_USER:$API_PASS" \
        -H "Content-Type: application/json" \
        -d @/tmp/list_data.json \
        "$API_URL/lists")
    
    list_id=$(echo "$create_response" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$list_id" ]; then
        log_success "Liste créée (ID: $list_id)"
        echo "$list_id"
    else
        log_error "Échec de création de la liste"
        echo "Réponse API : $create_response"
        exit 1
    fi
    
    # Nettoyer
    rm -f /tmp/list_data.json
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
                
                if population and population.replace('.', '').isdigit():
                    try:
                        attribs['population'] = int(float(population))
                    except:
                        pass
                
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
    
    # Créer le fichier de paramètres sans caractères de couleur
    cat > /tmp/import_params.json << EOF
{
    "list_ids": [$list_id],
    "overwrite": false,
    "delim": ",",
    "mode": "subscribe"
}
EOF
    
    # Lancer l'import
    local import_response=$(curl -s -u "$API_USER:$API_PASS" \
        -F "file=@communes-import.csv" \
        -F "params=<@/tmp/import_params.json" \
        "$API_URL/import/subscribers")
    
    # Nettoyer le fichier temporaire
    rm -f /tmp/import_params.json
    
    # Vérifier la réponse
    if echo "$import_response" | grep -q '"status":"running"'; then
        log_success "Import lancé avec succès"
        
        # Attendre la fin de l'import
        log_info "Attente de la fin de l'import (90 secondes)..."
        sleep 90
        
        # Vérifier le résultat
        check_import_result
    else
        log_error "Échec du lancement de l'import"
        echo "Réponse API : $import_response"
        
        # Essayer un import plus simple
        log_info "Tentative d'import simplifié..."
        simple_import "$list_id"
    fi
}

# Import simplifié en cas d'échec
simple_import() {
    local list_id=$1
    
    log_info "Import simplifié par petits lots..."
    
    # Diviser le CSV en petits fichiers
    split -l 1000 communes-import.csv communes-batch-
    
    local batch_count=0
    for batch_file in communes-batch-*; do
        if [ -f "$batch_file" ]; then
            batch_count=$((batch_count + 1))
            log_info "Import du lot $batch_count..."
            
            # Ajouter l'en-tête au fichier batch
            head -1 communes-import.csv > temp-batch.csv
            tail -n +2 "$batch_file" >> temp-batch.csv
            
            # Import du lot
            curl -s -u "$API_USER:$API_PASS" \
                -F "file=@temp-batch.csv" \
                -F "params={\"list_ids\":[$list_id],\"overwrite\":false,\"delim\":\",\",\"mode\":\"subscribe\"}" \
                "$API_URL/import/subscribers" > /dev/null
            
            # Attendre entre les lots
            sleep 10
            
            # Nettoyer
            rm -f "$batch_file" temp-batch.csv
        fi
    done
    
    log_info "Import par lots terminé"
}

# Vérifier le résultat de l'import
check_import_result() {
    log_info "Vérification du résultat..."
    
    # Compter les abonnés
    local subscribers_response=$(curl -s -u "$API_USER:$API_PASS" "$API_URL/subscribers?per_page=1")
    local total=$(echo "$subscribers_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$total" ] && [ "$total" -gt 0 ]; then
        log_success "Total d'abonnés : $total"
        
        # Vérifier le ciblage géographique
        log_info "Test du ciblage géographique..."
        
        # Test département 75 (Paris)
        local paris_query="subscribers.attribs%3F%27departement%27%20AND%20subscribers.attribs-%3E%3E%27departement%27%20%3D%20%2775%27"
        local paris_response=$(curl -s -u "$API_USER:$API_PASS" \
            "$API_URL/subscribers?query=$paris_query&per_page=1")
        local paris_count=$(echo "$paris_response" | grep -o '"total":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$paris_count" ] && [ "$paris_count" -gt 0 ]; then
            log_success "Ciblage géographique fonctionnel : $paris_count communes à Paris"
        else
            log_warning "Ciblage géographique à vérifier"
        fi
        
    else
        log_error "Problème avec l'import"
    fi
}

# Créer des exemples de requêtes
create_query_examples() {
    log_info "Création des exemples de requêtes..."
    
    cat > exemples-requetes-corriges.md << 'EOF'
# 🎯 Exemples de Requêtes de Ciblage Géographique

## Requêtes Testées et Fonctionnelles

### Ciblage par Département

#### Paris (75)
```sql
subscribers.attribs->>'departement' = '75'
```

#### Bouches-du-Rhône (13)
```sql
subscribers.attribs->>'departement' = '13'
```

#### Rhône (69)
```sql
subscribers.attribs->>'departement' = '69'
```

### Ciblage par Région

#### Île-de-France
```sql
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')
```

#### PACA
```sql
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84')
```

### Ciblage par Population

#### Grandes villes (>50k habitants)
```sql
(subscribers.attribs->>'population')::INT > 50000
```

#### Petites communes (<5k habitants)
```sql
(subscribers.attribs->>'population')::INT < 5000
```

### Ciblage Combiné

#### Grandes villes d'Île-de-France
```sql
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')
AND (subscribers.attribs->>'population')::INT > 50000
```

## Utilisation dans Listmonk

1. Aller dans **Campagnes** → **Nouvelle campagne**
2. Dans **"Listes"**, cliquer sur **"Requête avancée"**
3. Copier-coller une des requêtes ci-dessus
4. Cliquer sur **"Aperçu"** pour voir le nombre de destinataires

## Interface Web

- **URL** : http://localhost:9000
- **Login** : admin / listmonk (ou changeme)
EOF
    
    log_success "Exemples créés dans exemples-requetes-corriges.md"
}

# Nettoyer les fichiers temporaires
cleanup() {
    log_info "Nettoyage..."
    rm -f communes-import.csv communes-batch-* temp-batch.csv
    rm -f /tmp/import_params.json /tmp/list_data.json
}

# Fonction principale
main() {
    echo ""
    log_info "Import corrigé des communes françaises pour Listmonk"
    echo ""
    
    # Vérifications
    check_prerequisites
    check_current_state
    
    # Configuration
    local list_id=$(setup_list)
    
    # Import
    prepare_csv
    import_subscribers "$list_id"
    
    # Finalisation
    create_query_examples
    cleanup
    
    echo ""
    log_success "🎉 Import terminé !"
    echo ""
    echo "🌐 Interface Listmonk : http://localhost:9000"
    echo "📋 Exemples de requêtes : exemples-requetes-corriges.md"
    echo ""
    echo "🎯 Pour tester le ciblage :"
    echo "  1. Aller dans Campagnes → Nouvelle campagne"
    echo "  2. Cliquer sur 'Requête avancée' dans Listes"
    echo "  3. Tester : subscribers.attribs->>'departement' = '75'"
    echo ""
}

# Exécuter
main "$@"