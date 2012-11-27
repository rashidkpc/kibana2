$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), "lib")

# Load all the libs
Dir['./lib/*.rb'].each{ |f| load f }
require 'optparse'

app = KibanaApp
OptionParser.new { |op|
  op.on('-p port',   "set the port (default is #{KibanaConfig::KibanaPort})") { |val| app.set :port, Integer(val) }
  op.on('-o addr',   'set the host (default is 0.0.0.0)')             { |val| app.set :bind, val }
  op.on('-e env',    'set the environment (default is development)')  { |val| app.set :environment, val.to_sym }
  op.on('-s server', 'specify rack server/handler (default is thin)') { |val| app.set :server, val }
  op.on('-x',        'turn on the mutex lock (default is off)')       {       app.set :lock, true }
}.parse!(ARGV.dup)

app.run!
