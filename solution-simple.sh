#!/bin/bash

# Solution simple pour l'intégration des communes françaises
# Utilise les fonctionnalités natives de Listmonk

echo "🏛️ SOLUTION SIMPLE - COMMUNES FRANÇAISES"
echo "========================================"
echo ""
echo "Cette solution utilise les fonctionnalités NATIVES de Listmonk :"
echo "• Import des communes avec attributs géographiques"
echo "• Création de listes dynamiques avec requêtes SQL"
echo "• Interface de campagne native pour le ciblage"
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

# Configuration simple
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="listmonk"
DB_NAME="listmonk"
DB_PASSWORD="listmonk"

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

# Démarrer Listmonk simple
start_simple_listmonk() {
    log_info "Démarrage de Listmonk simple..."
    
    # Arrêter les anciens conteneurs
    docker stop $(docker ps -q --filter "name=listmonk") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=listmonk") 2>/dev/null || true
    
    # Créer docker-compose simple
    cat > docker-compose-simple.yml << 'EOF'
version: '3.8'

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
      LISTMONK_db__host: "db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk"
      LISTMONK_db__password: "listmonk"
      LISTMONK_db__database: "listmonk"
      LISTMONK_db__ssl_mode: "disable"
    restart: unless-stopped

volumes:
  listmonk_db_data:
EOF

    # Démarrer les services
    docker-compose -f docker-compose-simple.yml up -d
    
    log_info "Attente du démarrage de Listmonk..."
    sleep 30
    
    # Installer Listmonk
    docker exec listmonk_app ./listmonk --install --yes
    
    log_success "Listmonk démarré sur http://localhost:9000"
}

# Importer les communes avec attributs
import_communes_with_attributes() {
    log_info "Import des communes avec attributs géographiques..."
    
    # Créer le script d'import Python
    cat > import_simple.py << 'EOF'
import csv
import json
import psycopg2
import uuid
from datetime import datetime

def import_communes():
    try:
        # Connexion à la base de données
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="listmonk",
            user="listmonk",
            password="listmonk"
        )
        cur = conn.cursor()
        
        print("✅ Connexion à la base de données établie")
        
        # Créer une liste par défaut
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
        list_id = cur.fetchone()[0]
        
        print(f"✅ Liste 'Communes France' créée (ID: {list_id})")
        
        # Lire et importer le CSV
        with open('mairielist.csv', 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            
            count = 0
            batch = []
            batch_size = 1000
            unique_emails = set()
            
            for row in reader:
                try:
                    email = row.get('email', '').strip()
                    nom_commune = row.get('nom_commune', '').strip()
                    
                    # Ignorer les doublons et emails invalides
                    if not email or '@' not in email or email.lower() in unique_emails:
                        continue
                    
                    unique_emails.add(email.lower())
                    
                    # Créer les attributs géographiques
                    attribs = {
                        'commune': nom_commune,
                        'departement': row.get('departement_numero', '').strip(),
                        'code_postal': row.get('zipcode', '').strip(),
                        'population': row.get('population_commune', '').strip(),
                        'code_insee': row.get('code_insee', '').strip(),
                        'ville': row.get('city', '').strip(),
                        'region': row.get('state', '').strip(),
                        'telephone': row.get('phone', '').strip(),
                        'site_web': row.get('website', '').strip(),
                        'adresse': row.get('address1', '').strip()
                    }
                    
                    # Nettoyer les attributs vides
                    attribs = {k: v for k, v in attribs.items() if v and v.lower() not in ['nan', 'null', '']}
                    
                    # Convertir la population en entier si possible
                    if 'population' in attribs:
                        try:
                            attribs['population'] = int(float(attribs['population']))
                        except:
                            del attribs['population']
                    
                    # Normaliser le département (2 chiffres)
                    if 'departement' in attribs:
                        try:
                            dept_num = int(attribs['departement'])
                            attribs['departement'] = f"{dept_num:02d}"
                        except:
                            pass
                    
                    # Préparer l'insertion
                    subscriber_uuid = str(uuid.uuid4())
                    subscriber_data = (
                        subscriber_uuid,
                        email,
                        nom_commune or email.split('@')[0],
                        json.dumps(attribs, ensure_ascii=False),
                        'enabled',
                        datetime.now(),
                        datetime.now()
                    )
                    
                    batch.append((subscriber_data, subscriber_uuid, list_id))
                    count += 1
                    
                    # Insérer par batch
                    if len(batch) >= batch_size:
                        insert_batch(cur, batch)
                        batch = []
                        print(f"📊 Importé {count} communes...")
                
                except Exception as e:
                    print(f"⚠️  Erreur ligne {count}: {e}")
                    continue
            
            # Insérer le dernier batch
            if batch:
                insert_batch(cur, batch)
            
            conn.commit()
            print(f"🎉 Import terminé : {count} communes importées")
            
            cur.close()
            conn.close()
            
            return count
            
    except Exception as e:
        print(f"❌ Erreur d'import : {e}")
        return 0

def insert_batch(cur, batch):
    try:
        # Insérer les abonnés
        subscriber_data = [item[0] for item in batch]
        cur.executemany("""
            INSERT INTO subscribers (uuid, email, name, attribs, status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (email) DO NOTHING
        """, subscriber_data)
        
        # Associer à la liste
        for _, subscriber_uuid, list_id in batch:
            cur.execute("""
                INSERT INTO subscriber_lists (subscriber_id, list_id, status, created_at, updated_at)
                SELECT s.id, %s, 'confirmed', NOW(), NOW()
                FROM subscribers s
                WHERE s.uuid = %s
                ON CONFLICT DO NOTHING
            """, (list_id, subscriber_uuid))
        
    except Exception as e:
        print(f"❌ Erreur insertion batch: {e}")

if __name__ == "__main__":
    import_communes()
EOF

    # Installer psycopg2 et exécuter l'import
    pip3 install psycopg2-binary > /dev/null 2>&1
    python3 import_simple.py
    
    # Nettoyer
    rm -f import_simple.py
    
    log_success "Import terminé"
}

# Créer les listes de ciblage géographique
create_targeting_lists() {
    log_info "Création des listes de ciblage géographique..."
    
    # Créer le script de création des listes
    cat > create_lists.py << 'EOF'
import psycopg2
import uuid
from datetime import datetime

def create_targeting_lists():
    try:
        conn = psycopg2.connect(
            host="localhost",
            port=5432,
            database="listmonk",
            user="listmonk",
            password="listmonk"
        )
        cur = conn.cursor()
        
        # Listes par région
        regions = [
            ("Île-de-France", "subscribers.attribs->>'departement' IN ('75', '77', '78', '91', '92', '93', '94', '95')"),
            ("PACA", "subscribers.attribs->>'departement' IN ('04', '05', '06', '13', '83', '84')"),
            ("Occitanie", "subscribers.attribs->>'departement' IN ('09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82')"),
            ("Nouvelle-Aquitaine", "subscribers.attribs->>'departement' IN ('16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87')"),
            ("Auvergne-Rhône-Alpes", "subscribers.attribs->>'departement' IN ('01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74')"),
        ]
        
        # Listes par taille de population
        population_ranges = [
            ("Petites communes (< 2000 hab)", "(subscribers.attribs->>'population')::INT < 2000"),
            ("Communes moyennes (2000-10000 hab)", "(subscribers.attribs->>'population')::INT BETWEEN 2000 AND 10000"),
            ("Grandes communes (10000-50000 hab)", "(subscribers.attribs->>'population')::INT BETWEEN 10000 AND 50000"),
            ("Métropoles (> 50000 hab)", "(subscribers.attribs->>'population')::INT > 50000"),
        ]
        
        # Listes par département (quelques exemples)
        departments = [
            ("Paris (75)", "subscribers.attribs->>'departement' = '75'"),
            ("Nord (59)", "subscribers.attribs->>'departement' = '59'"),
            ("Rhône (69)", "subscribers.attribs->>'departement' = '69'"),
            ("Bouches-du-Rhône (13)", "subscribers.attribs->>'departement' = '13'"),
        ]
        
        all_lists = regions + population_ranges + departments
        
        for name, query in all_lists:
            try:
                list_uuid = str(uuid.uuid4())
                cur.execute("""
                    INSERT INTO lists (uuid, name, type, optin, tags, query, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (name) DO NOTHING
                """, (
                    list_uuid,
                    f"🎯 {name}",
                    'public',
                    'single',
                    '["ciblage-geo"]',
                    query,
                    datetime.now(),
                    datetime.now()
                ))
                print(f"✅ Liste créée : {name}")
            except Exception as e:
                print(f"⚠️  Erreur création liste {name}: {e}")
        
        conn.commit()
        cur.close()
        conn.close()
        
        print("🎉 Toutes les listes de ciblage créées !")
        
    except Exception as e:
        print(f"❌ Erreur création listes : {e}")

if __name__ == "__main__":
    create_targeting_lists()
EOF

    python3 create_lists.py
    rm -f create_lists.py
    
    log_success "Listes de ciblage créées"
}

# Créer le guide d'utilisation
create_usage_guide() {
    log_info "Création du guide d'utilisation..."
    
    cat > GUIDE_UTILISATION_SIMPLE.md << 'EOF'
# 🎯 Guide d'Utilisation - Ciblage Géographique des Communes

## ✅ Système Opérationnel

Votre système de ciblage géographique pour les communes françaises est maintenant prêt !

### 🌐 Accès
- **Interface web** : http://localhost:9000
- **Utilisateur** : admin
- **Mot de passe** : listmonk

## 🎯 Comment Utiliser le Ciblage Géographique

### 1. Créer une Campagne
1. Allez sur http://localhost:9000
2. Cliquez sur **"Campagnes"** → **"Nouvelle campagne"**
3. Remplissez les informations de base

### 2. Sélectionner les Destinataires
Dans la section **"Listes"**, vous trouverez des listes prêtes à l'emploi :

#### 🏛️ Par Région
- `🎯 Île-de-France` - Tous les départements d'IDF
- `🎯 PACA` - Région Provence-Alpes-Côte d'Azur
- `🎯 Occitanie` - Région Occitanie
- `🎯 Nouvelle-Aquitaine` - Région Nouvelle-Aquitaine
- `🎯 Auvergne-Rhône-Alpes` - Région Auvergne-Rhône-Alpes

#### 👥 Par Taille de Population
- `🎯 Petites communes (< 2000 hab)` - Villages et petites communes
- `🎯 Communes moyennes (2000-10000 hab)` - Communes de taille moyenne
- `🎯 Grandes communes (10000-50000 hab)` - Grandes villes
- `🎯 Métropoles (> 50000 hab)` - Grandes métropoles

#### 🗺️ Par Département (exemples)
- `🎯 Paris (75)` - Uniquement Paris
- `🎯 Nord (59)` - Département du Nord
- `🎯 Rhône (69)` - Département du Rhône
- `🎯 Bouches-du-Rhône (13)` - Département des Bouches-du-Rhône

### 3. Ciblage Avancé avec Requêtes SQL

Pour un ciblage plus précis, utilisez l'option **"Requête SQL"** :

#### Exemples de Requêtes

**Communes d'Île-de-France avec plus de 10 000 habitants :**
```sql
subscribers.attribs->>'departement' IN ('75', '77', '78', '91', '92', '93', '94', '95') 
AND (subscribers.attribs->>'population')::INT > 10000
```

**Petites communes rurales (< 1000 hab) hors IDF :**
```sql
(subscribers.attribs->>'population')::INT < 1000 
AND subscribers.attribs->>'departement' NOT IN ('75', '77', '78', '91', '92', '93', '94', '95')
```

**Communes du Sud de la France :**
```sql
subscribers.attribs->>'departement' IN ('04', '05', '06', '13', '83', '84', '09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82')
```

**Communes avec un site web :**
```sql
subscribers.attribs->>'site_web' IS NOT NULL 
AND subscribers.attribs->>'site_web' != ''
```

## 📊 Attributs Disponibles

Chaque commune dispose des attributs suivants :

| Attribut | Description | Exemple |
|----------|-------------|---------|
| `commune` | Nom de la commune | "Marseille" |
| `departement` | Code département | "13" |
| `code_postal` | Code postal | "13001" |
| `population` | Nombre d'habitants | 850000 |
| `code_insee` | Code INSEE | "13055" |
| `ville` | Nom de ville | "Marseille" |
| `region` | Région | "PACA" |
| `telephone` | Téléphone mairie | "04..." |
| `site_web` | Site web | "marseille.fr" |
| `adresse` | Adresse | "2 quai du Port" |

## 🔍 Syntaxe des Requêtes

### Opérateurs de Base
```sql
-- Égalité
subscribers.attribs->>'departement' = '75'

-- Liste de valeurs
subscribers.attribs->>'departement' IN ('75', '92', '93')

-- Comparaison numérique
(subscribers.attribs->>'population')::INT > 50000

-- Plage de valeurs
(subscribers.attribs->>'population')::INT BETWEEN 1000 AND 10000

-- Recherche textuelle
subscribers.attribs->>'commune' LIKE '%Saint%'

-- Vérifier l'existence
subscribers.attribs->>'site_web' IS NOT NULL
```

### Combinaisons
```sql
-- ET logique
subscribers.attribs->>'departement' = '75' AND (subscribers.attribs->>'population')::INT > 10000

-- OU logique
subscribers.attribs->>'departement' = '75' OR subscribers.attribs->>'departement' = '92'

-- Négation
subscribers.attribs->>'departement' NOT IN ('75', '92', '93')
```

## 🚀 Exemples d'Utilisation

### Campagne pour les Grandes Métropoles
**Objectif** : Cibler les grandes villes françaises
**Liste** : `🎯 Métropoles (> 50000 hab)`

### Campagne Régionale IDF
**Objectif** : Communication spécifique à l'Île-de-France
**Liste** : `🎯 Île-de-France`

### Campagne Villages Ruraux
**Objectif** : Cibler les petites communes rurales
**Requête SQL** :
```sql
(subscribers.attribs->>'population')::INT < 2000 
AND subscribers.attribs->>'departement' NOT IN ('75', '92', '93', '94')
```

## 🛠️ Maintenance

### Vérifier les Données
```bash
# Redémarrer le système
docker-compose -f docker-compose-simple.yml restart

# Voir les logs
docker-compose -f docker-compose-simple.yml logs -f

# Arrêter le système
docker-compose -f docker-compose-simple.yml down
```

### Statistiques
Connectez-vous à l'interface pour voir :
- Nombre total de communes importées
- Répartition par région
- Statistiques de population

## 🎉 Avantages de cette Solution

✅ **Simple** : Utilise les fonctionnalités natives de Listmonk
✅ **Flexible** : Requêtes SQL personnalisables
✅ **Performant** : Base de données PostgreSQL optimisée
✅ **Maintenable** : Pas de modifications du code source
✅ **Évolutif** : Facile d'ajouter de nouveaux critères

---

**🇫🇷 Votre système de ciblage géographique est prêt à l'emploi !**
EOF

    log_success "Guide d'utilisation créé : GUIDE_UTILISATION_SIMPLE.md"
}

# Vérification finale
final_verification() {
    log_info "Vérification finale..."
    
    # Vérifier l'accès web
    if curl -s http://localhost:9000 > /dev/null 2>&1; then
        log_success "Interface web accessible"
    else
        log_error "Interface web non accessible"
    fi
    
    # Vérifier les données
    if command -v psql &> /dev/null; then
        communes_count=$(PGPASSWORD=listmonk psql -h localhost -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM subscribers;" 2>/dev/null | tr -d ' ')
        if [ -n "$communes_count" ] && [ "$communes_count" -gt 0 ]; then
            log_success "Communes importées : $communes_count"
        fi
        
        lists_count=$(PGPASSWORD=listmonk psql -h localhost -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM lists WHERE name LIKE '🎯%';" 2>/dev/null | tr -d ' ')
        if [ -n "$lists_count" ] && [ "$lists_count" -gt 0 ]; then
            log_success "Listes de ciblage créées : $lists_count"
        fi
    fi
}

# Afficher les instructions finales
show_final_instructions() {
    echo ""
    log_success "🎉 SOLUTION SIMPLE DÉPLOYÉE AVEC SUCCÈS !"
    echo ""
    echo "📊 Accès au système :"
    echo "  • Interface web : http://localhost:9000"
    echo "  • Utilisateur : admin"
    echo "  • Mot de passe : listmonk"
    echo ""
    echo "🎯 Utilisation :"
    echo "  1. Allez sur http://localhost:9000"
    echo "  2. Créez une nouvelle campagne"
    echo "  3. Sélectionnez une liste de ciblage (🎯 ...)"
    echo "  4. Ou utilisez une requête SQL personnalisée"
    echo ""
    echo "📚 Documentation :"
    echo "  • Guide complet : GUIDE_UTILISATION_SIMPLE.md"
    echo "  • Documentation Listmonk : https://listmonk.app/docs/querying-and-segmentation/"
    echo ""
    echo "🛠️ Commandes utiles :"
    echo "  • Redémarrer : docker-compose -f docker-compose-simple.yml restart"
    echo "  • Arrêter : docker-compose -f docker-compose-simple.yml down"
    echo ""
}

# Fonction principale
main() {
    echo ""
    read -p "Démarrer la solution simple ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Déploiement annulé."
        exit 0
    fi
    
    echo ""
    log_info "🚀 DÉBUT DU DÉPLOIEMENT SIMPLE"
    echo ""
    
    check_prerequisites
    start_simple_listmonk
    import_communes_with_attributes
    create_targeting_lists
    create_usage_guide
    final_verification
    show_final_instructions
}

# Exécuter
main "$@"