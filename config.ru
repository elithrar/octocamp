require 'bundler/setup'
require 'sinatra/base'

# The project root directory
$root = ::File.dirname(__FILE__)

use Rack::CanonicalHost, ENV['CANONICAL_HOST'] if ENV['CANONICAL_HOST']

class SinatraStaticServer < Sinatra::Base

  get(/.+/) do
    cache_control :public, :max_age => 7200
    send_sinatra_file(request.path) {404}
  end

  not_found do
    send_sinatra_file('404.html') {"Sorry, I cannot find #{request.path}"}
    cache_control :no_cache, :max_age => 0
  end

  def send_sinatra_file(path, &missing_file_block)
    file_path = File.join(File.dirname(__FILE__), 'public',  path)
    file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i  
    File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
  end

end

use Rack::Deflater

run SinatraStaticServer