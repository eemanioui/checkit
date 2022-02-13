require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
     size_of_todos(list) > 0 && size_of_incompleted_todos(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def size_of_todos(list)
    list[:todos].size
  end

  def size_of_incompleted_todos(list)
    list[:todos].reject {|todo| todo[:completed] }.size 
  end

  # takes an array of hashes and reorders them while keeping record of their origianl index.
  # it then yields each sorted hash with its original index to the explicit block
  # this feature is intended exculsievly for the `lists` view template.
   def sort_lists(lists, &block)
    sorted_list = sorted(lists) {|list| list_complete?(list) ? 1 : 0 }
    sorted_list.each(&block)
  end

  def sort_todos(list, &block)
    sorted_list = sorted(list) { |todo| todo[:completed] ? 1 : 0 }
    sorted_list.each(&block)
  end


  def sorted(list, &block)
    list.map
        .with_index {|item, index| [item, index] }
        .sort_by {|item, index| yield(item) }
  end

=begin
# Important Notes: Line 32 & Line 37
  Ruby doesn't provide any built-in mechanism for comparing boolean values(`true` and `false`). 
  I took advantage of the way `Enumerable#sort_by` works in order to sort boolean values based on integer values which do implement comparison(<=>) in their class.
  `Enumerable#sort_by` works in 3 steps:
      1. It yields each element of the caller collection to the block, and caches the return value of the block at each iteration temporarily.
      2. sorts all of the block's cached returned values from step 1, which correspond to elements in the calling collection
      3. returns a new sorted collection object(e.i Array), within which elements are sorted based on the sorted return values of th block from step # 2.
  Note: This only works if the values returned by the block at each initial iteration(step #1) implement a comparison method and are of the same class(side_note: this could possibly be overidden with custom classes/objects)
  example: suppose at step # 1, you invoke a custom method within the block. if the method returns `nil`,`fale`, `true` or raises an exception for any of the passed in elements, the method will not work.
=end
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
