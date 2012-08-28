require 'rubygems'
require 'daemons'

# Thanks to Patrick McKenzie http://www.kalzumeus.com/2010/01/15/deploying-sinatra-on-ubuntu-in-which-i-employ-a-secretary/
# *** Make sure /var/spool/sinatra/pid exists ***

pwd = Dir.pwd
Daemons.run_proc('kibana.rb', {:dir_mode => :normal, :dir => "/var/spool/sinatra/pid"}) do
  Dir.chdir(pwd)
  exec "ruby kibana.rb"
end