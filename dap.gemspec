# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'dap/version'

Gem::Specification.new do |s|
  s.name        = 'dap'
  s.version     = Dap::VERSION
  s.required_ruby_version = '>= 2.6'
  s.authors     = [
      'Rapid7 Research'
  ]
  s.email       = [
      'research@rapid7.com'
  ]
  s.homepage    = "https://www.github.com/rapid7/dap"
  s.summary     = %q{DAP: The Data Analysis Pipeline}
  s.description = %q{
    DAP reads data using an input plugin, transforms it through a series of filters, and prints it out again
    using an output plugin. Every record is treated as a document (aka: hash/dict) and filters are used to
    reduce, expand, and transform these documents as they pass through. Think of DAP as a mashup between
    sed, awk, grep, csvtool, and jq, with map/reduce capabilities.
  }.gsub(/\s+/, ' ').strip

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  # ---- Dependencies ----

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'cucumber'
  s.add_development_dependency 'aruba'

  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'oj'
  s.add_runtime_dependency 'htmlentities'
  s.add_runtime_dependency 'net-dns'
  s.add_runtime_dependency 'bit-struct'
  s.add_runtime_dependency 'geoip-c'
  s.add_runtime_dependency 'recog'
  s.add_runtime_dependency 'maxmind-db'
end
