if ENV["KIBANA_CONFIG"]
    require ENV["KIBANA_CONFIG"]
else
    require File.expand_path("./KibanaConfig.rb")
end

require 'rubygems'
require 'date'
require 'rss/maker'
require 'yaml'
require 'compat'
require 'gon-sinatra'
require 'client_request'
require 'id_request'
require 'kransient_url'
require 'query'
require 'kelastic'
require 'version'
require 'kibana-app'
