require 'listen'
require 'rack'
require 'fixed_gear/builder'
require 'benchmark'

module FixedGear
  class Server
    def initialize(site)
      @site = site
    end
    attr_reader :site

    def root
      site.root.to_s
    end

    def start
      select_files = -> changed, dir do
        dir = dir.to_s
        changed.partition { |path| path.start_with?(dir) }
      end

      listener = Listen.to(root) do |*changed|
        changed = changed.flatten
        _build, changed = select_files[changed, site.build_dir.to_s]
        source, changed = select_files[changed, site.source_dir.to_s]
        p changed: changed
        @needs_build = true if source.any?
        @needs_reload = true if changed.any?
      end

      listener.start # not blocking

      builder = FixedGear::Builder.new(site)
      builder.load_config

      @reload = -> {
        @server&.stop
        exec $0, *ARGV
      }

      @build = -> {
        begin
          builder.call
        rescue => error
          warn error
          warn error.backtrace
          warn "~"*80
        end
      }

      @needs_build = true # start with a fresh build

      threads = [
        Thread.new do
          loop do
            sleep 0.2
            (@needs_build = false;  puts Benchmark.measure('build', &@build) ) if @needs_build
            (@needs_reload = false; puts Benchmark.measure('reload', &@reload)) if @needs_reload
          end
        end,

        Thread.new {
          Rack::Server.new(app: site.to_app, logger: FixedGear.logger).start { |server| @server = server }
        },
      ]

      threads.each &:join
    end
  end
end
