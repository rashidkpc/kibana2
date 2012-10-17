require 'rubygems'
require 'daemons'
require 'pathname'

# Thanks to Patrick McKenzie http://www.kalzumeus.com/2010/01/15/deploying-sinatra-on-ubuntu-in-which-i-employ-a-secretary/
# *** Make sure /var/spool/sinatra/pid exists ***
pid_dir = "/var/spool/sinatra/pid"

if File.directory? pid_dir
  # Get the full path to this script's directory since Daemons does a chdir to
  # / just after forking..
  scriptdir = Pathname.new(File.dirname(__FILE__)).realpath
  Daemons.run_proc('kibana.rb', {:dir_mode => :normal, :dir => pid_dir}) do
    Dir.chdir(scriptdir)
    exec "ruby kibana.rb"
  end
else
  puts "#{pid_dir} does not exist."
  puts "Please create it or change pid_dir in #{__FILE__}"  
end
