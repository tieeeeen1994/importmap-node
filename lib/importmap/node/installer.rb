# frozen_string_literal: true

require 'fileutils'
require 'json'

module Importmap
  module Node
    class Installer
      JS_DEST = 'vendor/javascript'
      CONFIG_FILE = 'config/importmap_node.json'

      def initialize(root: Rails.root)
        @root         = Pathname.new(root)
        @node_modules = @root.join('node_modules')
        @importmap    = @root.join('config', 'importmap.rb')
        @config_file  = @root.join(CONFIG_FILE)
      end

      def install(package)
        resolved_name = yarn_add(package)
        pkg_name = resolved_name || resolve_package_name(package)
        pkg_meta = read_package_meta(pkg_name)
        js_files = vendor_js(pkg_name, pkg_meta)
        pin_importmap(pkg_name, js_files)
        record_package(package)

        summarize(pkg_name, js_files)
      end

      def uninstall(package)
        pkg_name = resolve_package_name(package)
        pkg_meta = read_package_meta(pkg_name)
        js_files = vendored_js_files(pkg_name, pkg_meta)

        yarn_remove(pkg_name)
        delete_files(JS_DEST, js_files)
        unpin_importmap(pkg_name)
        unrecord_package(package)

        summarize_removal(pkg_name, js_files)
      end

      def update
        packages = load_packages
        if packages.empty?
          puts "No packages tracked in #{CONFIG_FILE}."
          return
        end
        yarn_up_dependencies
        puts "Re-vendoring #{packages.size} package(s)..."
        packages.each { |pkg| revendor(pkg) }
      end

      private

      def yarn_add(package)
        return yarn_add_repo(package) if repo_url?(package)

        yarn_arg = package.start_with?('file:') ? file_package_arg(package) : package
        puts "Running: yarn add #{yarn_arg}"
        system("yarn add #{yarn_arg}", chdir: @root.to_s) or raise "yarn add failed for #{package}"
        nil
      end

      def yarn_add_repo(package)
        deps_before = current_dependencies.keys
        puts "Running: yarn add #{package}"
        system("yarn add #{package}", chdir: @root.to_s) or raise "yarn add failed for #{package}"
        new_keys = current_dependencies.keys - deps_before
        raise "Could not determine package name after yarn add #{package}" if new_keys.empty?

        new_keys.first
      end

      def file_package_arg(package)
        "#{local_package_name(package)}@#{package}"
      end

      def yarn_remove(pkg_name)
        puts "Running: yarn remove #{pkg_name}"
        system("yarn remove #{pkg_name}", chdir: @root.to_s) or raise "yarn remove failed for #{pkg_name}"
      end

      def yarn_up_dependencies
        pkg_json = @root.join('package.json')
        deps     = JSON.parse(pkg_json.read).fetch('dependencies', {}).keys
        return if deps.empty?

        puts "Running: yarn up #{deps.join(' ')}"
        system("yarn up #{deps.join(' ')}", chdir: @root.to_s) or raise 'yarn up failed'
      end

      def repo_url?(package)
        return false if package.start_with?('file:')

        package.match?(%r{\Ahttps?://|\Agit[+:]|\Agithub:|\Abitbucket:|\Agitlab:}) ||
          (!package.start_with?('@') && package.include?('/'))
      end

      def current_dependencies
        pkg_json = @root.join('package.json')
        return {} unless pkg_json.exist?

        JSON.parse(pkg_json.read).fetch('dependencies', {})
      end

      def revendor(package)
        pkg_name = resolve_package_name(package)
        pkg_meta = read_package_meta(pkg_name)
        js_files = vendor_js(pkg_name, pkg_meta)
        pin_importmap(pkg_name, js_files)
        summarize(pkg_name, js_files)
      end

      def resolve_package_name(package)
        return local_package_name(package) if package.start_with?('file:')
        return repo_package_name(package) if repo_url?(package)

        package
      end

      def local_package_name(package)
        path = package.sub(/^file:/, '')
        local_pkg_json = File.expand_path(File.join(path, 'package.json'), @root.to_s)
        JSON.parse(File.read(local_pkg_json))['name']
      end

      def repo_package_name(package)
        deps = current_dependencies
        match = deps.find { |_name, spec| spec == package || spec.include?(package) || package.include?(spec) }
        match ? match.first : package
      end

      def read_package_meta(pkg_name)
        path = @node_modules.join(pkg_name, 'package.json')
        raise "Cannot find #{path}. Did yarn add succeed?" unless path.exist?

        JSON.parse(path.read)
      end

      def vendor_js(pkg_name, meta)
        file = meta['module'] || meta['main'] || 'index.js'
        src  = @node_modules.join(pkg_name, file)
        return [] unless src.exist?

        dest_dir = @root.join(JS_DEST)
        FileUtils.mkdir_p(dest_dir)
        dest = dest_dir.join(src.basename)
        FileUtils.cp(src, dest)
        [dest.basename.to_s]
      end

      def vendored_js_files(pkg_name, meta)
        file = meta['module'] || meta['main'] || 'index.js'
        src  = @node_modules.join(pkg_name, file)
        src.exist? ? [src.basename.to_s] : []
      end

      def delete_files(dest, filenames)
        filenames.each do |name|
          path = @root.join(dest, name)
          if path.exist?
            path.delete
            puts "  Deleted: #{dest}/#{name}"
          end
        end
      end

      def pin_importmap(pkg_name, js_files)
        return if js_files.empty? || !@importmap.exist?

        pin_line = "pin \"#{pkg_name}\", to: \"#{js_files.first}\""
        write_pin(pkg_name, pin_line)
      end

      def write_pin(pkg_name, pin_line)
        content = @importmap.read
        if content.match?(/pin ['"]{1}#{Regexp.escape(pkg_name)}['"]{1}/)
          @importmap.write(content.gsub(/pin ['"]{1}#{Regexp.escape(pkg_name)}['"]{1}[^\n]*/, pin_line))
          puts "  Updated pin: #{pin_line}"
        else
          @importmap.open('a') { |f| f.puts pin_line }
          puts "  Added pin: #{pin_line}"
        end
      end

      def unpin_importmap(pkg_name)
        return unless @importmap.exist?

        content     = @importmap.read
        new_content = content.gsub(/\n?pin ['"]#{Regexp.escape(pkg_name)}['"][^\n]*/, '')
        return unless content != new_content

        @importmap.write(new_content)
        puts "  Removed pin for #{pkg_name} from config/importmap.rb"
      end

      def summarize(pkg_name, js_files)
        puts "\n#{pkg_name} installed:"
        js_files.each { |f| puts "  JS: vendor/javascript/#{f}" }
        puts '  Pinned in config/importmap.rb' unless js_files.empty?
      end

      def summarize_removal(pkg_name, js_files)
        puts "\n#{pkg_name} removed:"
        js_files.each { |f| puts "  JS: #{JS_DEST}/#{f}" }
      end

      def load_packages
        return [] unless @config_file.exist?

        JSON.parse(@config_file.read)['packages'] || []
      end

      def record_package(package)
        packages = load_packages
        return if packages.include?(package)

        packages << package
        @config_file.write(JSON.pretty_generate('packages' => packages))
      end

      def unrecord_package(package)
        packages = load_packages
        return unless packages.delete(package)

        @config_file.write(JSON.pretty_generate('packages' => packages))
      end
    end
  end
end
