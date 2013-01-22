require 'bundler/setup'
require 'sinatra/base'
require 'rack/contrib'
require 'rack-canonical-host'

# The project root directory
$root = ::File.dirname(__FILE__)

class SinatraStaticServer < Sinatra::Base

  get %r{(/.*[^\/])$} do
    redirect "#{params[:captures].first}/"
  end

  get(/.+/) do
    expires 3600, :public, :must_revalidate
    send_sinatra_file(request.path) {404}
  end

  not_found do
    expires 0, :public, :no_cache
    send_sinatra_file('404.html') {"Sorry, I cannot find #{request.path}"}
  end

  configure :production do
    require 'newrelic_rpm'
  end

  def send_sinatra_file(path, &missing_file_block)
    file_path = File.join(File.dirname(__FILE__), 'public',  path)
    file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i  
    File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
  end

end

if ENV['CANONICAL_HOST']
  use Rack::CanonicalHost, ENV['CANONICAL_HOST'], ignore: ['media.eatsleeprepeat.net', 'static.eatsleeprepeat.net']
end

use Rack::Deflater

run SinatraStaticServer