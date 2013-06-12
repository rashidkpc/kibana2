#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'
require 'pathname'
require 'fileutils'

# Get the full path to this script's directory since Daemons does a chdir to
# / just after forking..
scriptdir = Pathname.new(File.dirname(__FILE__)).realpath

# store pidfile in tmp dir
pid_dir = File.join(scriptdir, "tmp")

# after creating the log dir make sure
# the kibana user has write access.
# otherwise it is silently ignored and
# no log file will be generated
log_dir = '/var/log/kibana'

begin
  FileUtils.mkdir(log_dir)
  puts "log dir #{log_dir} created."
rescue Errno::EEXIST
  puts "log dir #{log_dir} exists."
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

script = 'kibana.rb'

options = {
    :dir_mode => :normal,
    :dir => pid_dir,
    :monitor => true,
    :log_dir => log_dir,
    :log_output => true,
    :backtrace => true
}

Daemons.run_proc(script, options) do
  Dir.chdir(scriptdir)
  exec "ruby #{script}"
end
