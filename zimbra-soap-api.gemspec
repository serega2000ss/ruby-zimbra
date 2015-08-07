# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)
require "zimbra/version"

Gem::Specification.new do |s|
  s.name = "zimbra-soap-api"
  s.version = Zimbra::VERSION

  s.authors = ["Derek Kastner","Matt Wilson","Philippe Green","Greenview Data, Inc.","Patricio Bruna"]
  s.date = '2015-08-07'
  s.description = 'Interface to Zimbra management API'
  s.summary = %q{SOAP Interface to Zimbra}
  s.email = %q{development@greenviewdata.com}
  s.homepage = "https://github.com/pbruna/ruby-zimbra"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 1.9.2'

  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"
  s.add_runtime_dependency 'curb'
  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'handsoap'
end
