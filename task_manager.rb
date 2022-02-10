require 'sinatra'
require 'sinatra/reloader' if development?
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
  erb :new_list, layout: :layout
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

get "/lists/:id" do |id|
  @index = id.to_i  
  valid_list = session[:lists][@index]
  redirect '/' unless valid_list

  erb :todo
end

post "/lists/:id" do |id|
  todo = params[:todo_name]
  valid_list = session[:lists][id.to_i]
  valid_list[:todos] << todo
  
  redirect "/lists"
end


# returns a String error message if the name is invalid. returns nil if the name is valid.
def invalid?(list_name)
  unless list_name.size.between?(1, 100)
    return 'List name must be between 1 and 100 characters'
  end

  'List name must be unique.' if session[:lists].any? { |list| list[:name] == list_name }
end
