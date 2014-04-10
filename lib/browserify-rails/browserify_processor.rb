require "open3"
require "json"

module BrowserifyRails
  class BrowserifyProcessor < Tilt::Template
    BROWSERIFY_CMD = "./node_modules/.bin/browserify".freeze

    def prepare
    end

    def evaluate(context, locals, &block)
      if should_browserify? && commonjs_module?
        asset_dependencies(context.environment.paths).each do |path|
          context.depend_on(path)
        end

        browserify
      else
        data
      end
    end

    private

    def should_browserify?
      Rails.application.config.browserify_rails.paths.any? do |path_spec|
        path_spec === file
      end
    end

    # Is this a commonjs module?
    #
    # Be here as strict as possible, so that non-commonjs files are not
    # preprocessed.
    def commonjs_module?
      data.to_s.include?("module.exports") || dependencies.length > 0
    end

    # This primarily filters out required files from node modules
    #
    # @return [<String>] Paths of dependencies, that are in asset directories
    def asset_dependencies(asset_paths)
      dependencies.select do |path|
        path.start_with?(*asset_paths)
      end
    end

    # @return [<String>] Paths of files, that this file depends on
    def dependencies
      @dependencies ||= run_browserify("--list").lines.map(&:strip).select do |path|
        # Filter the temp file, where browserify caches the input stream
        File.exists?(path)
      end
    end

    def browserify
      if Rails.application.config.browserify_rails.source_map_environments.include?(Rails.env)
        options = "-d"
      else
        options = ""
      end

      run_browserify(options)
    end

    def browserify_cmd
      cmd = File.join(Rails.root, BROWSERIFY_CMD)

      if !File.exist?(cmd)
        raise BrowserifyRails::BrowserifyError.new("browserify could not be found at #{cmd}. Please run npm install.")
      end

      cmd
    end

    # Run browserify
    #
    # @raise [BrowserifyRails::BrowserifyError] if browserify does not succeed
    # @param options [String] Options for browserify
    # @return [String] Output on standard out
    def run_browserify(options)
      command = "#{browserify_cmd} #{options}"

      output = `#{command} #{file}`

      if !$?.success?
        raise BrowserifyRails::BrowserifyError.new("Error while running `#{command}`")
      end

      output
    end
  end
end
