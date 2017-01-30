require "fixed_gear/version"

module FixedGear
  autoload :Site, 'fixed_gear/site'
  autoload :Builder, 'fixed_gear/builder'
  autoload :Server, 'fixed_gear/server'

  class << self
    def logger
      @logger ||= Logger.new($stdout)
    end

    attr_accessor :no_digest_paths
  end

  self.no_digest_paths = Set.new

  Renderers = Hash.new {|hash, key| raise ArgumentError, "couldn't find a renderer for #{key.inspect} among #{hash.keys.inspect}"}
end
