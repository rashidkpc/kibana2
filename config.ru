require 'kibana'
require 'rubygems'
require 'sinatra'

set :environment, ENV['RACK_ENV'].to_sym
set :app_file,     'kibana.rb'
disable :run

run Sinatra::Application
