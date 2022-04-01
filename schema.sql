-- creating table to hold all the todo lists
CREATE TABLE IF NOT EXISTS lists (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

-- creating a table to hold all the todos
CREATE TABLE IF NOT EXISTS todos (
  id serial PRIMARY KEY,
  name text NOT NULL CHECK (length(name) > 0 ),
  completed boolean NOT NULL DEFAULT false,
  list_id integer NOT NULL REFERENCES lists(id) ON DELETE CASCADE
);