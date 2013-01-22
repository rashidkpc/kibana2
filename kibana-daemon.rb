#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
require 'pathname'
require 'fileutils'

# Get the full path to this script's directory since Daemons does a chdir to
# / just after forking..
scriptdir = Pathname.new(File.dirname(__FILE__)).realpath

# store pidfile
if ENV['PID_DIR']
  pid_dir=ENV['PID_DIR']
else
  pid_dir = File.join(scriptdir, "tmp")
end

if !File.directory?(pid_dir)
  if ARGV[0] == "start"
    puts "creating pid_dir #{pid_dir}"
    FileUtils.mkdir(pid_dir)
  else
    $stderr.puts "pid_dir #{pid_dir} does not exist"
    exit 1
  end
end

Daemons.run_proc('kibana.rb', {:dir_mode => :normal, :dir => pid_dir}) do
  Dir.chdir(scriptdir)
  exec "ruby kibana.rb"
end
