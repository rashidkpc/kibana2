#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
require 'pathname'
require 'fileutils'

# Get the full path to this script's directory since Daemons does a chdir to
# / just after forking..
scriptdir = Pathname.new(File.dirname(__FILE__)).realpath

# populate environment variables
pid_dir = !ENV['PID_DIR'].nil? ? ENV['PID_DIR'] : File.join(scriptdir, "tmp")
app_name = !ENV['KIBANA_APP'].nil? ? ENV['KIBANA_APP'] : "kibana"
log_output = !ENV['LOG_DIR'].nil? ? true : false
log_dir = log_output ? ENV['LOG_DIR'] : nil

options = {
          :dir_mode => :normal,
          :dir => pid_dir,
          :log_output => log_output,
          :log_dir => log_dir
          }

Daemons.run_proc(app_name, options) do
  Dir.chdir(scriptdir)
  exec "ruby kibana.rb"
end
