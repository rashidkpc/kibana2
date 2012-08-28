require 'rubygems'
require 'daemons'

#  Make sure /var/spool/sinatra/pid exists

pwd = Dir.pwd
Daemons.run_proc('kibana.rb', {:dir_mode => :normal, :dir => "/var/spool/sinatra/pid"}) do
  Dir.chdir(pwd)
  exec "ruby kibana.rb"
end