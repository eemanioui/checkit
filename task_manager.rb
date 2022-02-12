require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the `new list` form
get '/list/new' do
  erb :new_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error_message = invalid?(list_name)

  if error_message
    session[:error] = error_message
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:id' do |id|
  @list_id = id.to_i  
  @list = session[:lists][@list_id] # retruns a hash if a list exists or nil if there's no corresponding list

  redirect '/' unless @list

  erb :list
end

# Edit existing todo list
get '/lists/:id/edit' do
  @list_id= params[:id].to_i
  @list = session[:lists][@list_id]

  erb :edit_list
end

# update an existing todo list
post '/lists/:id' do |id|
  list_name = params[:list_name].strip
  error_message = invalid?(list_name)
  @list_id = id.to_i
  @list = session[:lists][@list_id]

  if error_message
    session[:error] = error_message
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:id/delete' do
  index = params[:id].to_i
  session[:lists].delete_at(index)
  session[:success] = "The list has been deleted."

  redirect "/lists"
end

# add a todo task to a list
post "/lists/:id/todos" do
  @list_id = params[:id].to_i
  @list  = session[:lists][@list_id]
  todo  = params[:todo].strip
  error = invalid_todo(todo)

  if error
    session[:error] = error
    erb :list
  else
    @list[:todos] <<  {name: todo, completed: false}
    session[:success] = 'Todo item has been added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a Todo from a list
post "/lists/:list_id/todos/:todo_id/delete" do |list_id, todo_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  todo_id = todo_id.to_i

  @list[:todos].delete_at(todo_id) 

  session[:success] = "Todo item has been deleted."

  redirect "/lists/#{@list_id}"
end 

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do |list_id, todo_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]
  todo_id = todo_id.to_i
  is_completed = params[:completed] == "true" 

  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "Todo item has been updated."

  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:list_id/complete_all" do |list_id|
  @list_id = list_id.to_i
  @list = session[:lists][@list_id]

  @list[:todos].each {|todo| todo[:completed] = true }

  session[:success] = "All todos have been completed."

  redirect "/lists/#{@list_id}"
end


# returns a String error message if the name is invalid. returns nil if the name is valid.
def invalid?(list_name)
  unless list_name.size.between?(1, 100)
    return "List name must be between 1 and 100 characters"
  end

  "List name must be unique." if session[:lists].any? { |list| list[:name] == list_name }
end

def invalid_todo(name)
  unless name.size.between?(1, 100)
    return "Todo name must be between 1 and 100 characters"
  end

  "Todo name must be unique." if session[:lists].any? { |list| list[:todos].any? {|todo| todo[:name] == name } }
end
