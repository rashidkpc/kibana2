require 'rubygems'
require 'daemons'

# Thanks to Patrick McKenzie http://www.kalzumeus.com/2010/01/15/deploying-sinatra-on-ubuntu-in-which-i-employ-a-secretary/
# *** Make sure /var/spool/sinatra/pid exists ***
pid_dir = "/var/spool/sinatra/pid"

if File.directory? pid_dir
  pwd = File.dirname(__FILE__) 
  Daemons.run_proc('kibana.rb', {:dir_mode => :normal, :dir => pid_dir}) do
    Dir.chdir(pwd)
    exec "ruby kibana.rb"
  end
else
  puts "#{pid_dir} does not exist."
  puts "Please create it or change pid_dir in #{__FILE__}"  
end
