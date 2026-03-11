# frozen_string_literal: true

namespace :importmap do
  namespace :node do
    desc 'Install a node package and vendor its JS/CSS files. Usage: rails importmap:node:install[package-name-or-url]'
    task :install, [:package] => :environment do |_t, args|
      package = args[:package]
      abort 'Usage: rails importmap:node:install[package-name-or-url]' if package.blank?

      Importmap::Node::Installer.new.install(package)
    end

    desc 'Remove a node package and delete its vendored JS files. Usage: rails importmap:node:remove[package-name]'
    task :remove, [:package] => :environment do |_t, args|
      package = args[:package]
      abort 'Usage: rails importmap:node:remove[package-name]' if package.blank?

      Importmap::Node::Installer.new.uninstall(package)
    end

    desc 'Re-vendor all packages tracked in config/importmap_node.json'
    task update: :environment do
      Importmap::Node::Installer.new.update
    end
  end
end
