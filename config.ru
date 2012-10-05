root_dir = File.dirname(__FILE__)
app_file = File.join(root_dir, 'kibana.rb')

require app_file

begin
  require 'sinatra'
rescue LoadError
  require 'rubygems'
  require 'sinatra'
end

set :environment, ENV['RACK_ENV'].to_sym
set :app_file, app_file
disable :run

run Sinatra::Application
