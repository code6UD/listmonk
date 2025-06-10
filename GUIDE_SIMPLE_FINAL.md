# 🎯 Guide Simple - Ciblage Géographique des Communes Françaises

## 🚀 Démarrage Rapide (3 étapes)

### Étape 1 : Vérifier et Initialiser
```bash
./verifier-et-initialiser.sh
```

### Étape 2 : Importer les Communes
```bash
./import-communes-simple.sh
```

### Étape 3 : Utiliser le Ciblage
Ouvrir `interface-ciblage-simple.html` dans votre navigateur

## 📋 Ce que fait cette solution

### ✅ Approche Simple
- **Utilise les fonctionnalités natives de Listmonk**
- **Pas de modification du code source**
- **Basé sur la documentation officielle**
- **Requêtes SQL standard PostgreSQL**

### ✅ Import Intelligent
- **Extraction automatique des départements**
- **Conversion de la population en nombre**
- **Attributs JSON structurés**
- **Validation des emails**

### ✅ Ciblage Géographique
- **Par département** : Paris (75), Marseille (13), etc.
- **Par région** : Île-de-France, PACA, etc.
- **Par population** : Métropoles, grandes villes, petites communes
- **Ciblage combiné** : Grandes villes d'IDF, petites communes PACA

## 🎯 Exemples de Requêtes

### Ciblage par Département
```sql
-- Paris
subscribers.attribs->>'departement' = '75'

-- Bouches-du-Rhône (Marseille)
subscribers.attribs->>'departement' = '13'
```

### Ciblage par Région
```sql
-- Île-de-France
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')

-- PACA
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84')
```

### Ciblage par Population
```sql
-- Métropoles (>100k habitants)
(subscribers.attribs->>'population')::INT > 100000

-- Petites communes (<10k habitants)
(subscribers.attribs->>'population')::INT < 10000
```

### Ciblage Combiné
```sql
-- Grandes villes d'Île-de-France
subscribers.attribs->>'departement' IN ('75','77','78','91','92','93','94','95')
AND (subscribers.attribs->>'population')::INT > 50000

-- Petites communes PACA
subscribers.attribs->>'departement' IN ('04','05','06','13','83','84')
AND (subscribers.attribs->>'population')::INT < 5000
```

## 🖥️ Utilisation dans Listmonk

### Méthode 1 : Interface de Ciblage
1. Ouvrir `interface-ciblage-simple.html`
2. Cliquer sur un bouton de ciblage
3. Copier la requête générée
4. Coller dans Listmonk

### Méthode 2 : Directement dans Listmonk
1. Aller dans **Campagnes** → **Nouvelle campagne**
2. Dans **"Listes"**, cliquer sur **"Requête avancée"**
3. Coller une requête SQL
4. Cliquer sur **"Aperçu"** pour voir le nombre de destinataires

## 📊 Structure des Données

Chaque commune importée a ces attributs :
```json
{
  "commune": "Paris",
  "departement": "75",
  "population": 2161000,
  "code_insee": "75056",
  "code_postal": "75001",
  "type": "mairie",
  "pays": "France"
}
```

## 🔧 Dépannage

### Problème : Services non démarrés
```bash
docker-compose -f docker-compose.mairies.yml up -d
```

### Problème : Base de données non accessible
```bash
docker logs listmonk_mairies_db
```

### Problème : Interface web non accessible
```bash
docker logs listmonk_mairies_app
```

### Problème : Aucune commune importée
```bash
# Vérifier l'API
curl -u admin:listmonk http://localhost:9000/api/health

# Relancer l'import
./import-communes-simple.sh
```

## 📈 Vérification du Succès

### 1. Interface Web Accessible
- URL : http://localhost:9000
- Login : admin / listmonk (ou changeme)

### 2. Communes Importées
```bash
# Compter les abonnés
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;"
```

### 3. Ciblage Fonctionnel
Dans Listmonk, tester la requête :
```sql
subscribers.attribs->>'departement' = '75'
```

## 🎯 Avantages de cette Solution

### ✅ Simplicité
- **3 scripts seulement**
- **Pas de configuration complexe**
- **Utilise les standards Listmonk**

### ✅ Fiabilité
- **Basé sur la documentation officielle**
- **Pas de modification du code source**
- **Compatible avec toutes les versions Listmonk**

### ✅ Maintenabilité
- **Code simple et lisible**
- **Facilement extensible**
- **Documentation claire**

### ✅ Performance
- **Requêtes SQL optimisées**
- **Index PostgreSQL natifs**
- **Pas de surcharge système**

## 📚 Documentation de Référence

- **Listmonk Querying** : https://listmonk.app/docs/querying-and-segmentation/
- **PostgreSQL JSON** : https://www.postgresql.org/docs/11/functions-json.html
- **Interface de ciblage** : `interface-ciblage-simple.html`

## 🎉 Résultat Final

Une fois tout configuré, vous aurez :

1. **~81 000 communes françaises** importées dans Listmonk
2. **Ciblage géographique** par département, région, population
3. **Interface simple** pour générer les requêtes
4. **Intégration native** avec Listmonk
5. **Campagnes ciblées** prêtes à l'envoi

---

**🎯 Cette solution simple et robuste vous permet de cibler précisément les communes françaises selon vos besoins de communication !**