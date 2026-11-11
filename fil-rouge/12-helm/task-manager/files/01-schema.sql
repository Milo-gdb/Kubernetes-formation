CREATE TABLE IF NOT EXISTS tasks (
  id         serial PRIMARY KEY,
  title      text        NOT NULL,
  done       boolean     NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Rôle utilisé par PostgREST pour les requêtes anonymes
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA public TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON tasks TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE tasks_id_seq TO web_anon;
INSERT INTO tasks (title) VALUES
  ('Découvrir les Pods'),
  ('Écrire un Deployment'),
  ('Exposer l''application avec un Service');
