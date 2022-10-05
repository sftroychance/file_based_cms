require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(filepath)
  content = File.read(filepath)
  extension = File.extname(filepath)

  case extension
  when '.txt'
    headers["Content-Type"] = "text/plain"
    content
  when '.md'
    erb render_markdown(content)
  end
end

def project_root
  File.expand_path("..", __FILE__ )
end

def data_path
  if ENV['RACK_ENV'] == "test"
    project_root + '/test/data'
  else
    project_root + '/data'
  end
end

def signed_in?
  !session[:user].nil?
end

def redirect_if_not_signed_in
  unless signed_in?
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
  end
end

def authorized_users
  YAML.load_file('users.yml')
end

def load_user_credentials
  credentials_file =
    if ENV['RACK_ENV'] == 'test'
      project_root + '/test/users.yml'
    else
      project_root + '/users.yml'
    end
  YAML.load_file(credentials_file)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials[username]
    BCrypt::Password.new(credentials[username]) == password
  else
    false
  end
end

# home page
get '/' do
  @files = Dir.glob(File.join(data_path, "*"))
                .map { |filename| File.basename(filename) }
  erb :index
end

# go to page to create new file
get '/new' do
  redirect_if_not_signed_in

  erb :new_file
end

# create new file
post '/new' do
  redirect_if_not_signed_in

  filename = params[:new_filename]

  path = File.join(data_path, filename)
  if filename.strip == ''
    session[:message] = 'A name is required.'
    status 422
    erb :new_file
  elsif File.exists?(path)
    session[:message] = "File already exists."
    status 422
    erb :new_file
  elsif !(filename.include?('.txt') || filename.include?('.md') )
    session[:message] = "You must add an extension: .md or .txt"
    status 422
    erb :new_file
  else
    File.open(path, 'w') {}
    session[:message] = "#{filename} was created."
    redirect '/'
  end
end

# delete file
post '/delete/:filename' do |filename|
  redirect_if_not_signed_in

  path = File.join(data_path, filename)
  File.delete(path)
  session[:message] = "#{filename} was deleted."
  redirect '/'
end

# view file contents
get '/:filename' do |filename|
  path = File.join(data_path, filename)

  if File.file?(path)
    load_file_content(path)
  else
    session[:message] = "#{filename} does not exist."
    redirect '/'
  end
end

# go to page to edit file contents
get '/:filename/edit' do |filename|
  redirect_if_not_signed_in

  @filepath = File.join(data_path, filename)
  @filename = filename

  erb :edit_file
end

# update edited file
post '/:filename' do |filename|
  redirect_if_not_signed_in

  @filepath = File.join(data_path, filename)

  File.write(@filepath, params[:content])

  session[:message] = "#{filename} has been updated"
  redirect '/'
end

# go to login page
get '/users/signin' do
  erb :user_login
end

# log in
post '/users/signin' do
  if valid_credentials?(params[:username], params[:password])
    session[:user] = params[:username]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid credentials'
    status 422
    erb :user_login
  end
end

# log out
post '/users/signout' do
  session.delete(:user)
  session[:message] = 'You have been signed out.'
  redirect '/'
end