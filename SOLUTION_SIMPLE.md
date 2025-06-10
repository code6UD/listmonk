# 🎯 Solution Simple - Ciblage Géographique Listmonk

## 🔍 Analyse du Problème

D'après la documentation officielle Listmonk, le ciblage se fait via des **requêtes SQL sur les attributs JSON** des abonnés.

## 📋 Plan Simple en 4 Étapes

### 1. ✅ Configuration de Base
- Listmonk fonctionnel avec docker-compose.mairies.yml
- Base de données PostgreSQL accessible
- Interface web opérationnelle

### 2. 📊 Import des Communes avec Attributs Corrects
Structure des attributs pour chaque commune :
```json
{
  "departement": "75",
  "population": "2161000", 
  "code_insee": "75056",
  "region": "Île-de-France"
}
```

### 3. 🎯 Requêtes SQL de Ciblage
Exemples de requêtes natives Listmonk :
```sql
-- Paris (département 75)
subscribers.attribs->>'departement' = '75'

-- Grandes villes (>100k habitants)
(subscribers.attribs->>'population')::INT > 100000

-- Île-de-France
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')

-- Petites communes PACA
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84') 
AND (subscribers.attribs->>'population')::INT < 5000
```

### 4. 🖥️ Interface Simple
- Boutons prédéfinis pour les ciblages courants
- Génération automatique des requêtes SQL
- Intégration dans l'interface native Listmonk

## 🚀 Mise en Œuvre Immédiate

### Étape 1 : Vérification Base
```bash
# Vérifier que Listmonk fonctionne
curl http://localhost:9000

# Vérifier la base de données
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;"
```

### Étape 2 : Import Simple
```bash
# Script d'import minimal et fonctionnel
./import-communes-simple.sh
```

### Étape 3 : Test des Requêtes
Dans l'interface Listmonk, tester :
```sql
subscribers.attribs->>'departement' = '75'
```

### Étape 4 : Interface de Ciblage
- Boutons JavaScript simples
- Génération de requêtes SQL
- Copie dans le champ de requête Listmonk

## 🎯 Objectif Final

Une interface simple avec des boutons :
- **Paris** → `subscribers.attribs->>'departement' = '75'`
- **IDF** → `subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')`
- **Grandes villes** → `(subscribers.attribs->>'population')::INT > 100000`
- **Petites communes** → `(subscribers.attribs->>'population')::INT < 2000`

## ✅ Avantages de cette Approche

1. **Simple** : Utilise les fonctionnalités natives de Listmonk
2. **Fiable** : Pas de modifications du code source
3. **Maintenable** : Basé sur la documentation officielle
4. **Extensible** : Facile d'ajouter de nouveaux ciblages

---

**🎯 Commençons par vérifier que Listmonk fonctionne, puis créons l'import simple !**