Warbler::Config.new do |config|

config.dirs = %w(lib)
config.webserver = "jetty"
config.includes = FileList['*.rb']

end
