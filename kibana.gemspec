Gem::Specification.new do |gem|
  gem.authors = ["Rashid Khan"]
  gem.description = %q{log search, visualization and analysis frontend for logstash+elasticsearch}
  gem.summary = %q{Kibana - log search, visualization and analysis}
  gem.homepage = "http://rashidkpc.github.com/Kibana/"
  gem.license = "MIT License"

  #gem.files = `git ls-files`.split($\)
  gem.name = "kibana"
  gem.require_paths = ["lib"]
  gem.version = "0.0.1"

  # Dependencies
gem.add_runtime_dependency 'sinatra'
gem.add_runtime_dependency 'json'
gem.add_runtime_dependency 'fastercsv'
gem.add_runtime_dependency 'tzinfo'
gem.add_runtime_dependency 'thin'

gem.add_development_dependency 'rspec'
gem.add_development_dependency 'rspec-mocks'

end
