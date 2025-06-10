# 🔧 Guide de Résolution - Problèmes de Base de Données

## 🚨 Problème Identifié

D'après votre sortie de `verification-finale.sh`, le problème principal est :
- ❌ **Base de données PostgreSQL non accessible**
- ❌ **Connexion à la base de données échouée**
- ✅ Application Listmonk en cours d'exécution
- ✅ Interface web accessible

## 🔍 Diagnostic Rapide

Exécutez d'abord le diagnostic rapide :
```bash
./quick-diagnosis.sh
```

## 🛠️ Solutions par Ordre de Priorité

### Solution 1 : Correction Automatique (Recommandée)
```bash
# Script de correction automatique
./fix-database-connection.sh
```

Ce script va :
- ✅ Vérifier et démarrer Docker si nécessaire
- ✅ Identifier les conteneurs existants
- ✅ Créer une configuration Docker propre
- ✅ Redémarrer les services correctement
- ✅ Tester la connexion à la base de données
- ✅ Initialiser Listmonk si nécessaire

### Solution 2 : Redémarrage Manuel
```bash
# Arrêter tous les conteneurs
docker-compose down

# Nettoyer les conteneurs orphelins
docker container prune -f

# Redémarrer avec une configuration propre
docker-compose up -d

# Attendre le démarrage (30 secondes)
sleep 30

# Vérifier l'état
docker ps
```

### Solution 3 : Recréation Complète
```bash
# Sauvegarder les données si nécessaire
docker-compose down

# Supprimer les volumes (ATTENTION : perte de données)
docker volume prune -f

# Recréer avec une configuration fraîche
./fix-database-connection.sh
```

## 🔧 Vérifications Spécifiques

### 1. État de Docker
```bash
# Vérifier que Docker fonctionne
docker ps

# Si Docker ne répond pas
sudo systemctl start docker
# ou
sudo dockerd > /tmp/docker.log 2>&1 &
```

### 2. État des Conteneurs
```bash
# Voir tous les conteneurs
docker ps -a

# Logs de la base de données
docker logs listmonk_db
# ou
docker logs listmonk_mairies_db

# Logs de l'application
docker logs listmonk_app
```

### 3. Test de Connexion Manuelle
```bash
# Tester la connexion PostgreSQL
docker exec -it listmonk_db psql -U listmonk -d listmonk

# Ou avec les anciennes credentials
docker exec -it listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies
```

## 🎯 Configuration Recommandée

### docker-compose.yml Optimal
```yaml
version: '3.8'

services:
  listmonk_db:
    image: postgres:13
    container_name: listmonk_db
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk
    volumes:
      - listmonk_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  listmonk_app:
    image: listmonk/listmonk:latest
    container_name: listmonk_app
    depends_on:
      listmonk_db:
        condition: service_healthy
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_db__host: "listmonk_db"
      LISTMONK_db__port: 5432
      LISTMONK_db__user: "listmonk"
      LISTMONK_db__password: "listmonk"
      LISTMONK_db__database: "listmonk"
      LISTMONK_db__ssl_mode: "disable"
    ports:
      - "9000:9000"
    volumes:
      - ./config.toml:/listmonk/config.toml:ro

volumes:
  listmonk_data:
```

### config.toml Optimal
```toml
[app]
address = "0.0.0.0:9000"
admin_username = "admin"
admin_password = "listmonk"

[db]
host = "listmonk_db"
port = 5432
user = "listmonk"
password = "listmonk"
database = "listmonk"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"
```

## 🚀 Après Correction

Une fois la base de données corrigée :

### 1. Vérification
```bash
./final-verification.sh
```

### 2. Import des Communes
```bash
# Test avec échantillon
./test-import-sample.sh

# Import complet
./import-all-communes.sh
```

### 3. Vérification Finale
```bash
./check-current-import.sh
```

## 🆘 Si Rien ne Fonctionne

### Diagnostic Complet
```bash
# Informations système
docker version
docker-compose version

# État des services
systemctl status docker

# Logs détaillés
docker-compose logs

# Espace disque
df -h

# Processus Docker
ps aux | grep docker
```

### Redémarrage Complet du Système
```bash
# Arrêter tout
docker-compose down
docker system prune -a -f

# Redémarrer Docker
sudo systemctl restart docker

# Recréer tout
./fix-database-connection.sh
```

## 📞 Support

### Scripts d'Aide Disponibles
- `./quick-diagnosis.sh` - Diagnostic rapide
- `./fix-database-connection.sh` - Correction automatique
- `./check-current-import.sh` - État de l'import
- `./final-verification.sh` - Vérification complète

### Commandes de Debug
```bash
# Voir les logs en temps réel
docker-compose logs -f

# Entrer dans le conteneur DB
docker exec -it listmonk_db bash

# Entrer dans le conteneur App
docker exec -it listmonk_app bash

# Vérifier les variables d'environnement
docker exec listmonk_app env | grep LISTMONK
```

---

## 🎯 Résumé des Actions

1. **Exécutez** : `./fix-database-connection.sh`
2. **Vérifiez** : `./quick-diagnosis.sh`
3. **Testez** : `./final-verification.sh`
4. **Importez** : `./import-all-communes.sh`

**🔧 La correction automatique devrait résoudre 90% des problèmes de base de données !**