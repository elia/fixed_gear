require 'sprockets'
require 'yaml'
require 'fileutils'

module FixedGear
  class Builder
    include FileUtils

    def initialize(site)
      @site = site
    end

    attr_reader :site

    def root
      site.root
    end

    module ContextExtensions
      def asset_path(path, options = {})
        link_asset(path)
        asset = environment.find_asset(path)
        if options[:digest] == false
          p "/#{asset.logical_path}"
        else
          p "/#{asset.digest_path}"
        end
      end

      def render(name, **locals)
        path = name.sub(%r{(/|^)([^/]+)}, '\1_\2')
        asset = depend_on_asset(path)
        extension = File.extname(asset.filename)
        ::FixedGear::Renderers[extension].call(self, asset, locals)
      end

      def data(name)
        asset = depend_on_asset("#{name}.yml")

        @data ||= {}
        @data[name.to_sym] ||= begin
          symbolize = nil
          strict_hash = -> hash, key { raise ArgumentError, "can't find key: #{key.inspect} in #{hash}" }
          symbolize_hash = -> hash {
            new_hash = Hash.new(&strict_hash)
            hash.each { |k,v| new_hash[k.to_sym] = symbolize[v] }
            new_hash
          }
          symbolize_array = -> array { array.map(&symbolize) }
          symbolize = -> v {
            case v
            when Hash then symbolize_hash[v]
            when Array then symbolize_array[v]
            else v
            end
          }

          data = YAML.safe_load(asset.source, [Date, Symbol])
          symbolize[data]
        end
      end
    end

    def environment
      @environment ||= begin
        environment = Sprockets::Environment.new
        environment.gzip = false
        environment.append_path site.source_dir
        environment.cache = Sprockets::Cache::FileStore.new("#{root}/tmp/cache")

        environment.context_class.class_eval do
          include ContextExtensions
        end
        environment
      end
    end

    def load_config
      config_file = site.root.join('config.rb')
      instance_eval(config_file.read, config_file.to_s, 1)
    end

    def manifest
      @manifest ||= Sprockets::Manifest.new(environment, site.build_dir)
    end

    def clean
      manifest.clean
    end

    def call
      manifest.clean(0, 0)
      manifest.compile('index.html')
      ::FixedGear.no_digest_paths.each do |path|
        site.build_dir.join(path).write environment[path]
      end
      # manifest.files.each do |path, data|
      #   if path.end_with?('.html')
      #     plain_path = path.sub(/-[a-z\d]+\.html$/, '.html')
      #     p from: path, to: plain_path
      #     rm plain_path if File.exist? plain_path
      #     site.build_dir.join(plain_path).open('w') {|f| f << environment[plain_path] }
      #   end
      # end

      puts "Done building."
    end
  end
end


# #!/usr/bin/env ruby
#
# puts "Loading builder..."
#
# require 'bundler/setup'
# require 'sprockets'
# require 'haml'
# require 'opal-sprockets'
# require 'sass'
# require 'bourbon'
# require 'yaml'
# require 'fileutils'
# require 'puma'
# extend FileUtils
#
# ROOT = root = File.expand_path("#{__dir__}/..")
#
# class HamlView
#   attr_reader :context
#
#   def root
#     ROOT
#   end
#
#   def initialize(environment, context)
#     @context = context
#     @environment = environment
#   end
#
#   def asset_path(name)
#     context.depend_on_asset(name)
#     context.link_asset(name)
#     '/'+@environment.find_asset(name).digest_path
#   end
#
#   def data(name)
#     context.depend_on_asset(name)
#     # @environment.find_asset(name, pipeline: :self).to_s
#     @data ||= {}
#     @data[name.to_sym] ||= JSON.parse(YAML.safe_load(File.read("#{root}/source/#{name}.yml"), [Date]).to_json, symbolize_names: true)
#   end
#
#   def render(name, **locals)
#     name = "_#{name}"
#     context.depend_on_asset(name+'.html')
#     source = File.read("#{root}/source/#{name}.haml")
#     p source: source
#     ::Haml::Engine.new(source).render(self, locals)
#   end
# end
#
# # Sprockets.register_mime_type 'text/haml', extensions: ['.haml']
# # Sprockets.register_mime_type 'text/html', extensions: ['.html']
# # Sprockets.register_transformer 'text/haml', 'text/html', -> input {
# #   context = input[:environment].context_class.new(input)
# #   view = HamlView.new(input[:environment], context)
# #   data = ::Haml::Engine.new(input[:data]).render(view)
# #   context.metadata.merge(data: data)
# # }
# #
# # environment = Sprockets::Environment.new
# # environment.gzip = false
# # (Opal.paths+["#{root}/source"]).each(&environment.method(:append_path))
# # # environment.cache = Sprockets::Cache::FileStore.new("#{root}/tmp/cache")
# # environment.context_class.class_eval do
# #   def asset_path(path, options = {})
# #     depend_on_asset(path)
# #     link_asset(path)
# #     asset = environment.find_asset(path)
# #     "/#{asset.digest_path}"
# #   end
# # end
# #
# # build_dir = "#{root}/build"
# # manifest = Sprockets::Manifest.new(environment, build_dir)
# # manifest.clean
# #
# # $build = -> {
# #   puts "Building..."
# #   manifest.compile('index.html')
# #   File.write("#{build_dir}/index.html", environment['index.html'].to_s)
# #   puts "Done building."
# # }
# #
# # if __FILE__ == $0
# #   # trap("USR1", &$build)
# #   $build.call
# # end
# #
# # module SprocketsStatic
# #   extend self
# #
# #   attr_accessor :environment, :manifest
# # end
# #
# # SprocketsStatic.environment = environment
# # SprocketsStatic.manifest = manifest
