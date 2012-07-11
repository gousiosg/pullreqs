# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pullreqs/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Georgios Gousios"]
  gem.email         = ["gousiosg@gmail.com"]
  gem.description   = %q{A framework for analysis of Github pull requests}
  gem.summary       = %q{Analyze Github pull requests}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "pullreqs"
  gem.require_paths = ["lib"]
  gem.version       = Pullreqs::VERSION
end
