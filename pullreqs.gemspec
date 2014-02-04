# -*- encoding: utf-8 -*-
require 'rake'

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
  gem.version       = 0.1

  gem.add_dependency "sequel", ['>= 3.35']
  gem.add_dependency "github-linguist", ['>= 2.3.4']
  gem.add_dependency "grit", ['>= 2.5.0']
  gem.add_dependency 'ghtorrent', ['>= 0.7.3']
  gem.add_dependency 'parallel', ['>= 0.7.1']
  gem.add_dependency 'erubis', ['>= 2.7']
end
