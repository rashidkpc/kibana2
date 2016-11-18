$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))

require 'rubygems'
require 'bundler/setup'
require 'kibana'

KibanaApp.run!
