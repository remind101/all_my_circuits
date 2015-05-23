# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'all_my_circuits/version'

Gem::Specification.new do |spec|
  spec.name          = "all_my_circuits"
  spec.version       = AllMyCircuits::VERSION
  spec.authors       = ["Vlad Yarotsky"]
  spec.email         = ["vlad@remind101.com"]

  spec.summary       = %q{Circuit Breaker library with support for rolling-window absolute/percentage thresholds}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/remind101/all_my_circuits"
  spec.license       = "BSD"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.6"
  spec.add_development_dependency "puma", "~> 2.11"
end
