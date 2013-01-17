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
require 'client_request'
require 'id_request'
require 'ktransient_url'
require 'query'
require 'kelastic'
require 'version'
require 'kibana-app'
