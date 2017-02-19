require 'listen'
require 'rack'
require 'fixed_gear/builder'
require 'benchmark'

module FixedGear
  class Server
    class Rack
      def initialize(environment)
        @environment = environment
      end

      def call(env)
        path = env['PATH_INFO'].sub(%r{\A/}, '')
        path = 'index.html' if path.empty?
        if FixedGear.no_digest_paths.include? path
          asset = @environment[path]
          env['PATH_INFO'] = "/#{asset.digest_path}" if asset
        end
        @environment.call(env)
      end

      def self.for_dir(dir)
        for_site FixedGear::Site.new(root: dir)
      end

      def self.for_site(site)
        builder = FixedGear::Builder.new(site)
        builder.load_config
        new(builder.environment)
      end
    end
  end
end
