# frozen_string_literal: true

require_relative 'lib/importmap/node/version'

Gem::Specification.new do |spec|
  spec.name        = 'importmap-node'
  spec.version     = Importmap::Node::VERSION
  spec.authors     = ['Tien']
  spec.email       = ['tieeeeen1994@gmail.com']
  spec.summary     = 'Install node packages as vendored assets in Rails via yarn'
  spec.license     = 'MIT'

  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1'
  spec.add_dependency 'railties', '>= 7.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.homepage = 'https://github.com/tieeeeen1994/importmap-node'
end
