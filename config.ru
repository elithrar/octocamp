require 'bundler/setup'
require 'sinatra/base'

# The project root directory
$root = ::File.dirname(__FILE__)

class SinatraStaticServer < Sinatra::Base

  set :static, true

  get('*.html') do
    set :static_cache_control, [:public, :max_age => 3600]
  end

  get('%r{\.(css)|(js)|(png)|(gif)|(jpg)|(ico)}') do
    set :static_cache_control, [:public, :max_age => 86400]
  end


  get(/.+/) do
    cache_control :public
    send_sinatra_file(request.path) {404}
  end

  not_found do
    send_sinatra_file('404.html') {"Sorry, I cannot find #{request.path}"}
  end

  def send_sinatra_file(path, &missing_file_block)
    file_path = File.join(File.dirname(__FILE__), 'public',  path)
    file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i  
    File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
  end

end

use Rack::Deflater

run SinatraStaticServer