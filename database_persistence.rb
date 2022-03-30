require 'pg'

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production? 
              PG.connect(ENV['DATABASE_URL']) 
          else
            PG.connect(dbname: "todos", user: "postgres")
          end
    @logger = logger
  end

  def find_list(id)
    sql = <<~SQL
          SELECT l.*, 
                COUNT(t.id) AS todos_count, 
                COUNT(NULLIF(t.completed, true)) AS remaining_todos_count
          FROM lists l
            LEFT JOIN todos t
            ON l.id = t.list_id
          WHERE l.id = $1
          GROUP BY l.id;
        SQL

    result = query(sql, id)

    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
            SELECT l.*, 
                  COUNT(t.id) AS todos_count, 
                  COUNT(NULLIF(t.completed, true)) AS remaining_todos_count
            FROM lists l
              LEFT JOIN todos t
              ON l.id = t.list_id
            GROUP BY l.id
            ORDER BY remaining_todos_count DESC, l.name;
          SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name) 
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1;"
    query(sql, id)
  end

  def update_list_name(list_id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    query(sql, new_name, list_id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2);"
    query(sql, list_id, todo_name)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $3 WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id, new_status)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2;"
    query(sql, true, list_id)
  end

  def disconnect
    @db.close
  end

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    result = query(sql, list_id)

    result.map do |tuple|
      {
        id: tuple["id"].to_i, 
        name: tuple["name"], 
        completed: tuple["completed"] == "t"
      }
    end
  end

  private
  
  def query(statement, *params)
    @logger.info("#{statement}: #{params}") #  outputs the sql query for debugging
    @db.exec_params(statement, params)
  end

  def tuple_to_list_hash(tuple)
    {
      id: tuple["id"].to_i, 
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      remaining_todos_count: tuple["remaining_todos_count"].to_i
    }
  end
end