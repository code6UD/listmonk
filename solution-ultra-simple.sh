#!/bin/bash

# Solution ultra-simple pour l'intégration des communes françaises
# Approche minimaliste avec Listmonk standard

echo "🏛️ SOLUTION ULTRA-SIMPLE - COMMUNES FRANÇAISES"
echo "=============================================="
echo ""
echo "Approche minimaliste :"
echo "• Listmonk standard sans modifications"
echo "• Import direct des communes avec attributs"
echo "• Utilisation des requêtes SQL natives"
echo ""

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

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if [ ! -f "mairielist.csv" ]; then
        log_error "Fichier mairielist.csv non trouvé"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Démarrer Listmonk avec installation automatique
start_listmonk_auto() {
    log_info "Démarrage de Listmonk avec installation automatique..."
    
    # Arrêter les anciens conteneurs
    docker stop $(docker ps -q --filter "name=listmonk") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=listmonk") 2>/dev/null || true
    
    # Créer docker-compose avec installation automatique
    cat > docker-compose-ultra.yml << 'EOF'
services:
  db:
    image: postgres:13
    container_name: listmonk_db
    environment:
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk
      POSTGRES_DB: listmonk
    ports:
      - "5432:5432"
    volumes:
      - listmonk_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: listmonk/listmonk:latest
    container_name: listmonk_app
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "9000:9000"
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_app__admin_username: "admin"
      LISTMONK_app__admin_password: "listmonk123"
      LISTMONK_db__host: "db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk"
      LISTMONK_db__password: "listmonk"
      LISTMONK_db__database: "listmonk"
      LISTMONK_db__ssl_mode: "disable"
    command: >
      sh -c "
        echo 'Attente de la base de données...' &&
        sleep 10 &&
        echo 'Installation de Listmonk...' &&
        ./listmonk --install --yes &&
        echo 'Démarrage de Listmonk...' &&
        ./listmonk
      "
    restart: unless-stopped

volumes:
  listmonk_db_data:
EOF

    # Démarrer les services
    docker-compose -f docker-compose-ultra.yml up -d
    
    log_info "Attente de l'installation et du démarrage de Listmonk..."
    sleep 60
    
    # Vérifier que Listmonk est accessible
    local max_attempts=30
    for attempt in $(seq 1 $max_attempts); do
        if curl -s http://localhost:9000 > /dev/null 2>&1; then
            log_success "Listmonk accessible sur http://localhost:9000"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Listmonk non accessible après $max_attempts tentatives"
            log_info "Logs de l'application :"
            docker logs listmonk_app --tail=20
            exit 1
        fi
        
        log_info "Attente de Listmonk... ($attempt/$max_attempts)"
        sleep 5
    done
}

# Importer les communes directement
import_communes_direct() {
    log_info "Import direct des communes..."
    
    # Créer le script d'import ultra-simple
    cat > import_ultra_simple.py << 'EOF'
import csv
import json
import psycopg2
import uuid
from datetime import datetime

def import_communes():
    try:
        # Connexion directe à la base
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="listmonk",
            user="listmonk",
            password="listmonk"
        )
        cur = conn.cursor()
        
        print("✅ Connexion établie")
        
        # Créer une liste simple
        list_uuid = str(uuid.uuid4())
        cur.execute("""
            INSERT INTO lists (uuid, name, type, optin, tags, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (name) DO NOTHING
        """, (
            list_uuid,
            'Communes France',
            'public',
            'single',
            '{}',
            datetime.now(),
            datetime.now()
        ))
        
        # Récupérer l'ID de la liste
        cur.execute("SELECT id FROM lists WHERE name = 'Communes France'")
        result = cur.fetchone()
        if not result:
            print("❌ Erreur création liste")
            return 0
        list_id = result[0]
        
        print(f"✅ Liste créée (ID: {list_id})")
        
        # Import du CSV
        count = 0
        unique_emails = set()
        
        with open('mairielist.csv', 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            for row in reader:
                try:
                    email = row.get('email', '').strip()
                    nom_commune = row.get('nom_commune', '').strip()
                    
                    if not email or '@' not in email or email.lower() in unique_emails:
                        continue
                    
                    unique_emails.add(email.lower())
                    
                    # Attributs simples
                    attribs = {}
                    
                    # Département (normalisé)
                    dept = row.get('departement_numero', '').strip()
                    if dept:
                        try:
                            attribs['departement'] = f"{int(dept):02d}"
                        except:
                            attribs['departement'] = dept
                    
                    # Population (convertie en entier)
                    pop = row.get('population_commune', '').strip()
                    if pop:
                        try:
                            attribs['population'] = int(float(pop))
                        except:
                            pass
                    
                    # Autres attributs utiles
                    for key, attr in [
                        ('nom_commune', 'commune'),
                        ('zipcode', 'code_postal'),
                        ('code_insee', 'insee'),
                        ('city', 'ville'),
                        ('state', 'region')
                    ]:
                        value = row.get(key, '').strip()
                        if value and value.lower() not in ['nan', 'null', '']:
                            attribs[attr] = value
                    
                    # Insérer l'abonné
                    subscriber_uuid = str(uuid.uuid4())
                    cur.execute("""
                        INSERT INTO subscribers (uuid, email, name, attribs, status, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (email) DO NOTHING
                    """, (
                        subscriber_uuid,
                        email,
                        nom_commune or email.split('@')[0],
                        json.dumps(attribs, ensure_ascii=False),
                        'enabled',
                        datetime.now(),
                        datetime.now()
                    ))
                    
                    # Associer à la liste
                    cur.execute("""
                        INSERT INTO subscriber_lists (subscriber_id, list_id, status, created_at, updated_at)
                        SELECT s.id, %s, 'confirmed', NOW(), NOW()
                        FROM subscribers s
                        WHERE s.uuid = %s
                        ON CONFLICT DO NOTHING
                    """, (list_id, subscriber_uuid))
                    
                    count += 1
                    
                    if count % 1000 == 0:
                        print(f"📊 {count} communes importées...")
                        conn.commit()
                
                except Exception as e:
                    print(f"⚠️  Erreur ligne {count}: {e}")
                    continue
        
        conn.commit()
        print(f"🎉 Import terminé : {count} communes")
        
        cur.close()
        conn.close()
        
        return count
        
    except Exception as e:
        print(f"❌ Erreur : {e}")
        return 0

if __name__ == "__main__":
    import_communes()
EOF

    # Installer psycopg2 et exécuter
    pip3 install psycopg2-binary > /dev/null 2>&1
    python3 import_ultra_simple.py
    
    # Nettoyer
    rm -f import_ultra_simple.py
    
    log_success "Import terminé"
}

# Créer le guide d'utilisation ultra-simple
create_simple_guide() {
    log_info "Création du guide d'utilisation..."
    
    cat > GUIDE_ULTRA_SIMPLE.md << 'EOF'
# 🎯 Guide Ultra-Simple - Ciblage Géographique

## ✅ Accès au Système

- **URL** : http://localhost:9000
- **Utilisateur** : admin
- **Mot de passe** : listmonk123

## 🎯 Comment Cibler les Communes

### 1. Créer une Campagne
1. Allez sur http://localhost:9000
2. Cliquez sur **"Campagnes"** → **"Nouvelle campagne"**
3. Remplissez le nom et l'objet

### 2. Sélectionner les Destinataires

#### Option A : Utiliser la Liste Complète
- Sélectionnez **"Communes France"** pour toutes les communes

#### Option B : Ciblage par Requête SQL
Cliquez sur **"Requête SQL"** et utilisez ces exemples :

**Cibler un département :**
```sql
subscribers.attribs->>'departement' = '75'
```

**Cibler plusieurs départements (Île-de-France) :**
```sql
subscribers.attribs->>'departement' IN ('75', '77', '78', '91', '92', '93', '94', '95')
```

**Cibler par population :**
```sql
(subscribers.attribs->>'population')::INT > 50000
```

**Petites communes :**
```sql
(subscribers.attribs->>'population')::INT < 2000
```

**Communes moyennes d'un département :**
```sql
subscribers.attribs->>'departement' = '13' 
AND (subscribers.attribs->>'population')::INT BETWEEN 5000 AND 20000
```

**Recherche par nom de commune :**
```sql
subscribers.attribs->>'commune' LIKE '%Saint%'
```

## 📊 Attributs Disponibles

| Attribut | Description | Exemple |
|----------|-------------|---------|
| `departement` | Code département | "75" |
| `population` | Nombre d'habitants | 50000 |
| `commune` | Nom de la commune | "Paris" |
| `code_postal` | Code postal | "75001" |
| `insee` | Code INSEE | "75056" |
| `ville` | Nom de ville | "Paris" |
| `region` | Région | "IDF" |

## 🔍 Exemples de Ciblage

### Grandes Métropoles
```sql
(subscribers.attribs->>'population')::INT > 100000
```

### Région PACA
```sql
subscribers.attribs->>'departement' IN ('04', '05', '06', '13', '83', '84')
```

### Communes rurales hors IDF
```sql
(subscribers.attribs->>'population')::INT < 5000 
AND subscribers.attribs->>'departement' NOT IN ('75', '77', '78', '91', '92', '93', '94', '95')
```

### Paris et petite couronne
```sql
subscribers.attribs->>'departement' IN ('75', '92', '93', '94')
```

## 🛠️ Maintenance

```bash
# Redémarrer
docker-compose -f docker-compose-ultra.yml restart

# Arrêter
docker-compose -f docker-compose-ultra.yml down

# Voir les logs
docker-compose -f docker-compose-ultra.yml logs -f
```

## 🎉 C'est Tout !

Votre système de ciblage géographique est prêt. Utilisez les requêtes SQL pour cibler précisément vos communes !
EOF

    log_success "Guide créé : GUIDE_ULTRA_SIMPLE.md"
}

# Vérification finale
final_check() {
    log_info "Vérification finale..."
    
    # Vérifier l'accès
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Interface accessible"
    else
        log_error "Interface non accessible"
        return 1
    fi
    
    # Vérifier les données
    if command -v psql &> /dev/null; then
        count=$(PGPASSWORD=listmonk psql -h localhost -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
        if [ -n "$count" ] && [ "$count" -gt 0 ]; then
            log_success "Communes importées : $count"
        else
            log_warning "Aucune commune trouvée"
        fi
    fi
}

# Instructions finales
show_instructions() {
    echo ""
    log_success "🎉 SOLUTION ULTRA-SIMPLE DÉPLOYÉE !"
    echo ""
    echo "🌐 Accès :"
    echo "  • URL : http://localhost:9000"
    echo "  • Utilisateur : admin"
    echo "  • Mot de passe : listmonk123"
    echo ""
    echo "🎯 Utilisation :"
    echo "  1. Créez une nouvelle campagne"
    echo "  2. Utilisez la liste 'Communes France' ou une requête SQL"
    echo "  3. Exemples dans GUIDE_ULTRA_SIMPLE.md"
    echo ""
    echo "📚 Documentation :"
    echo "  • Guide : GUIDE_ULTRA_SIMPLE.md"
    echo "  • Listmonk : https://listmonk.app/docs/querying-and-segmentation/"
    echo ""
}

# Fonction principale
main() {
    echo ""
    read -p "Démarrer la solution ultra-simple ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Annulé."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉPLOIEMENT ULTRA-SIMPLE"
    echo ""
    
    check_prerequisites
    start_listmonk_auto
    import_communes_direct
    create_simple_guide
    final_check
    show_instructions
}

# Exécuter
main "$@"