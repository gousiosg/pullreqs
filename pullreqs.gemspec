# -*- encoding: utf-8 -*-
require 'rake'

Gem::Specification.new do |gem|
  gem.authors       = ["Georgios Gousios"]
  gem.email         = ["gousiosg@gmail.com"]
  gem.description   = %q{A framework for the analysis of Github pull requests}
  gem.summary       = %q{Analyze Github pull requests}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "pullreqs"
  gem.require_paths = ["lib"]
  gem.version       = 0.1

  gem.add_dependency "sequel", ['>= 3.35']
  gem.add_dependency "github-linguist", ['>= 4.5']
  gem.add_dependency "rugged", ['>= 0.22']
  gem.add_dependency 'parallel', ['>= 0.7.1']
  gem.add_dependency 'mongo', ['>= 1.12', '< 2.0' ]
  gem.add_dependency 'travis', ['>= 1.7']
  gem.add_dependency 'sequel', ['>= 4.23']
  gem.add_dependency 'trollop', ['>= 2.1.2']
  gem.add_dependency 'mysql2', ['>= 0.3']

end
