class KibanaConfig < Settingslogic
  source File.join(File.dirname(__FILE__), '../config', 'config.yml')
  namespace ENV['SINATRA_ENV'] ? ENV['SINATRA_ENV'] : 'defaults'
  load!
end