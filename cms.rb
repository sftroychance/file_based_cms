require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'

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

get '/' do
  @files = Dir.glob(File.join(data_path, "*"))
                .map { |filename| File.basename(filename) }

  erb :index
end

get '/new' do
  erb :new_file
end

post '/new' do
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

post '/delete/:filename' do |filename|
  path = File.join(data_path, filename)
  File.delete(path)
  session[:message] = "#{filename} was deleted."
  redirect '/'
end

get '/:filename' do |filename|
  path = File.join(data_path, filename)

  if File.file?(path)
    load_file_content(path)
  else
    session[:message] = "#{filename} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do |filename|
  @filepath = File.join(data_path, filename)
  @filename = filename

  erb :edit_file
end

post '/:filename' do |filename|
  @filepath = File.join(data_path, filename)

  File.write(@filepath, params[:content])

  session[:message] = "#{filename} has been updated"
  redirect '/'
end

get '/users/signin' do
  erb :user_login
end

post '/users/signin' do
  if params[:username] == 'admin' and params[:password] == 'secret'
    session[:user] = params[:username]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid credentials'
    status 422
    erb :user_login
  end
end

post '/users/signout' do
  session.delete(:user)
  session[:message] = 'You have been signed out.'
  redirect '/'
end