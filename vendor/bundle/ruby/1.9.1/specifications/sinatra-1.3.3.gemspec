# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "sinatra"
  s.version = "1.3.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Blake Mizerany", "Ryan Tomayko", "Simon Rozet", "Konstantin Haase"]
  s.date = "2012-08-19"
  s.description = "Sinatra is a DSL for quickly creating web applications in Ruby with minimal effort."
  s.email = "sinatrarb@googlegroups.com"
  s.extra_rdoc_files = ["README.de.rdoc", "README.es.rdoc", "README.fr.rdoc", "README.hu.rdoc", "README.jp.rdoc", "README.ko.rdoc", "README.pt-br.rdoc", "README.pt-pt.rdoc", "README.rdoc", "README.ru.rdoc", "README.zh.rdoc", "LICENSE"]
  s.files = ["README.de.rdoc", "README.es.rdoc", "README.fr.rdoc", "README.hu.rdoc", "README.jp.rdoc", "README.ko.rdoc", "README.pt-br.rdoc", "README.pt-pt.rdoc", "README.rdoc", "README.ru.rdoc", "README.zh.rdoc", "LICENSE"]
  s.homepage = "http://www.sinatrarb.com/"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sinatra", "--main", "README.rdoc", "--encoding=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.11"
  s.summary = "Classy web-development dressed in a DSL"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.3.6", "~> 1.3"])
      s.add_runtime_dependency(%q<rack-protection>, ["~> 1.2"])
      s.add_runtime_dependency(%q<tilt>, [">= 1.3.3", "~> 1.3"])
    else
      s.add_dependency(%q<rack>, [">= 1.3.6", "~> 1.3"])
      s.add_dependency(%q<rack-protection>, ["~> 1.2"])
      s.add_dependency(%q<tilt>, [">= 1.3.3", "~> 1.3"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.3.6", "~> 1.3"])
    s.add_dependency(%q<rack-protection>, ["~> 1.2"])
    s.add_dependency(%q<tilt>, [">= 1.3.3", "~> 1.3"])
  end
end
