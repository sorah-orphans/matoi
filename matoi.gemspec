# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'matoi/version'

Gem::Specification.new do |gem|
  gem.name          = "matoi"
  gem.version       = Matoi::VERSION
  gem.authors       = ["Shota Fukumori (sora_h)"]
  gem.email         = ["her@sorah.jp"]
  gem.description   = %q{Logs twitter's userstream into Groonga}
  gem.summary       = %q{Logs twitter's userstream into Groonga. Including Web Interface to search.}
  gem.homepage      = "https://github.com/sorah/matoi"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "rroonga"
  gem.add_dependency "twitter-stream"
  gem.add_dependency "oauth"
  gem.add_dependency "thor"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "fuubar"
end
