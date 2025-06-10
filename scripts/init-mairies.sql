-- Script d'initialisation pour les mairies françaises
-- Création des extensions nécessaires

-- Extension PostGIS pour les données géographiques
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Extension pour les UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extension pour les statistiques
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Création d'un index spatial si nécessaire (sera utilisé plus tard)
-- CREATE INDEX IF NOT EXISTS idx_subscribers_location ON subscribers USING GIST(location);

-- Configuration pour les données françaises
SET timezone = 'Europe/Paris';

-- Commentaire pour traçabilité
COMMENT ON DATABASE listmonk_mairies IS 'Base de données Listmonk pour les mairies françaises';
