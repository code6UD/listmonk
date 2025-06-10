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
