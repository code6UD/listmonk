# 🚀 Guide Rapide - Configuration Mairies

## 🎯 Votre Configuration Détectée

Vous utilisez la configuration spécialisée pour les mairies avec :
- **Fichier compose** : `docker-compose.mairies.yml`
- **Conteneurs** : `listmonk_mairies_*`
- **Base de données** : `listmonk_mairies` / `listmonk_mairies_2024`
- **Port DB** : `5433` (au lieu de 5432)

## 🔧 Solution Rapide (3 étapes)

### Étape 1 : Diagnostic
```bash
./check-mairies-status.sh
```

### Étape 2 : Correction Automatique
```bash
./fix-mairies-database.sh
```

### Étape 3 : Import des Communes
```bash
./import-mairies-fixed.sh
```

## 🚨 Si les Scripts N'Existent Pas

Les nouveaux scripts ne sont peut-être pas encore dans votre version. Utilisez les commandes manuelles :

### Redémarrer les Services
```bash
# Arrêter
docker-compose -f docker-compose.mairies.yml down

# Redémarrer
docker-compose -f docker-compose.mairies.yml up -d

# Attendre 30 secondes
sleep 30
```

### Vérifier l'État
```bash
# Conteneurs
docker ps | grep listmonk_mairies

# Base de données
docker exec listmonk_mairies_db pg_isready -U listmonk_mairies

# Test de connexion
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT 1;"
```

### Compter les Communes
```bash
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;"
```

## 🔍 Diagnostic Manuel

### 1. Vérifier Docker
```bash
docker ps -a | grep listmonk_mairies
```

### 2. Logs des Conteneurs
```bash
# Base de données
docker logs listmonk_mairies_db

# Application
docker logs listmonk_mairies_app

# Redis
docker logs listmonk_mairies_redis
```

### 3. Test de l'Interface
```bash
curl -I http://localhost:9000
```

## 🛠️ Solutions par Problème

### Problème : Base de données non accessible
```bash
# Redémarrer juste la DB
docker-compose -f docker-compose.mairies.yml restart db

# Vérifier les logs
docker logs listmonk_mairies_db
```

### Problème : Interface non accessible
```bash
# Redémarrer l'app
docker-compose -f docker-compose.mairies.yml restart app

# Vérifier les logs
docker logs listmonk_mairies_app
```

### Problème : Pas de communes importées
```bash
# Vérifier si Listmonk est initialisé
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'subscribers';"

# Si pas de tables, initialiser
docker exec listmonk_mairies_app ./listmonk --install --yes
```

## 📊 Import Manuel des Communes

Si les scripts automatiques ne fonctionnent pas :

### 1. Préparer le CSV
```bash
# Vérifier le fichier
head -5 mairielist.csv
wc -l mairielist.csv
```

### 2. Créer une Liste via l'Interface
1. Aller sur http://localhost:9000
2. Se connecter (admin / changeme)
3. Créer une liste "Communes France"

### 3. Import via l'Interface
1. Aller dans "Abonnés" > "Import"
2. Sélectionner le fichier `mairielist.csv`
3. Mapper les colonnes :
   - `email` → Email
   - `nom_commune` → Nom
   - Autres colonnes → Attributs
4. Lancer l'import

## 🎯 Vérification Finale

### Interface Web
- **URL** : http://localhost:9000
- **Login** : admin / changeme

### Base de Données
- **Host** : localhost:5433
- **User** : listmonk_mairies
- **Password** : listmonk_mairies_2024
- **Database** : listmonk_mairies

### Adminer (Interface DB)
- **URL** : http://localhost:8082
- Utiliser les mêmes identifiants DB

## 🚀 Après Correction

Une fois que tout fonctionne :

1. **Vérifiez les données** :
   ```bash
   docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) FROM subscribers;"
   ```

2. **Testez le ciblage géographique** :
   - Aller sur l'interface web
   - Créer une campagne
   - Utiliser les filtres par département/population

3. **Sauvegardez la configuration** :
   ```bash
   docker-compose -f docker-compose.mairies.yml config > config-backup.yml
   ```

## 📞 Support

Si vous avez encore des problèmes :

1. **Exécutez** : `./check-mairies-status.sh` (si disponible)
2. **Partagez** les logs : `docker logs listmonk_mairies_db`
3. **Vérifiez** l'espace disque : `df -h`
4. **Redémarrez** complètement : `docker-compose -f docker-compose.mairies.yml down && docker-compose -f docker-compose.mairies.yml up -d`

---

**🎯 L'objectif est d'avoir tous les services en cours d'exécution et la base de données accessible pour pouvoir importer les 81k communes françaises !**