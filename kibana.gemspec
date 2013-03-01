# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version"

Gem::Specification.new do |gem|
  gem.authors = ["Rashid Khan"]
  gem.description = %q{log search, visualization and analysis frontend for logstash+elasticsearch}
  gem.summary = %q{Kibana - log search, visualization and analysis}
  gem.homepage = "http://rashidkpc.github.com/Kibana/"
  gem.license = "MIT License"

  gem.files = `git ls-files`.split("\n")
  gem.name = "kibana"
  gem.require_paths = ["lib"]
  gem.version = Kibana::VERSION
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  gem.add_runtime_dependency 'sinatra'
  gem.add_runtime_dependency 'json'
  gem.add_runtime_dependency 'fastercsv'
  gem.add_runtime_dependency 'daemons'
  gem.add_runtime_dependency 'tzinfo'
  gem.add_runtime_dependency 'thin' unless RUBY_PLATFORM =~ /java/i

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rspec-mocks'
  gem.add_development_dependency 'warbler'
end
