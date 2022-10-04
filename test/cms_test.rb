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

  def test_invalid_file
    get '/invalid_file.txt'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'invalid_file.txt does not exist'

    get '/'

    refute_includes last_response.body, 'invalid_file.txt does not exist'
  end

  def test_markdown_rendering
    create_document("about.md", "#The About File")

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>The About File</h1>'
  end

  def test_edit_document
    create_document("changes.txt", 'sample content')

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, '<button'

  end

  def test_update_document
    post '/changes.txt', content: 'new content'

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, 'changes.txt has been updated'

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end
end