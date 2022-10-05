ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

class CMSTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content='')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { "rack.session" => { user: "admin" } }
  end

  def test_index
    create_document("changes.txt")
    create_document("about.md")

    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'about.md'
  end

  def test_file
    create_document('history.txt', "history text")

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, 'history text'
  end

  def test_file_does_not_exist
    get '/invalid_file.txt'
    assert_equal 302, last_response.status
    assert_equal 'invalid_file.txt does not exist.', session[:message]
  end

  def test_markdown_rendering
    create_document("about.md", "#The About File")

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>The About File</h1>'
  end

  def test_edit_file
    create_document("changes.txt", 'sample content')

    get '/changes.txt/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '<button'
  end

  def test_edit_file_signed_out
    create_document("changes.txt", 'sample content')

    get '/changes.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_update_file
    post '/changes.txt', { content: 'new content' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been updated', session[:message]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_update_file_signed_out
    post '/changes.txt', { content: 'new content' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_new_file_form
    get '/new', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_new_file_form_signed_out
    get '/new', {}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_empty_filename
    post '/new', { new_filename: '' }, admin_session
    assert_equal 422, last_response.status

    assert_includes last_response.body, 'A name is required.'
  end

  def test_empty_filename_signed_out
    post '/new', { new_filename: '' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_filename_no_extension
    post '/new', { new_filename: 'no_extension' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'You must add an extension'
  end

  def test_fname_no_ext_signed_out
    post '/new', { new_filename: 'no_extension' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_dup_fname
    create_document("duplicate.txt")

    post '/new', { new_filename: 'duplicate.txt' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'File already exists.'
  end

  def test_dup_fname_signed_out
    create_document("duplicate.txt")

    post '/new', { new_filename: 'duplicate.txt' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_file
    post '/new', { new_filename: 'newfile.txt' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'newfile.txt was created.', session[:message]

    get '/'
    assert_includes last_response.body, 'newfile.txt'
  end

  def test_create_file_signed_out
    post '/new', { new_filename: 'newfile.txt' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_file_deletion
    create_document('deletable.txt')

    post '/delete/deletable.txt', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'deletable.txt was deleted.', session[:message]

    get last_response['Location']

    get '/'
    refute_includes last_response.body, 'deletable.txt'
  end

  def test_file_deletion_signed_out
    create_document('deletable.txt')

    post '/delete/deletable.txt', {}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_signin_page
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, '<input type="password"'
  end

  def test_successful_signin
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:user]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_failed_signin
    post '/users/signin', username: 'nobody', password: 'invalid'
    assert_equal 422, last_response.status
    assert_nil session[:user]
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_signout
    get '/', {}, { 'rack.session' => { user: 'admin' } }
    assert_includes last_response.body, 'Signed in as admin.'

    post '/users/signout'
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:user]
    assert_includes last_response.body, '<button type="submit">Sign in'
  end
end
