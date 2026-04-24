-- Create isolated databases for NewAPI gateway and Open WebUI frontend.
-- Runs only on first-time PostgreSQL initialization (empty pg_data volume).

CREATE DATABASE newapi_db;
CREATE DATABASE openwebui_db;
