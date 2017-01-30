require 'erb'

module FixedGear::ERB
  Renderer = -> context, asset, locals{
    binding = context.instance_eval { binding }
    locals.each { |name, value| binding.local_variable_set(name, value) }
    ERB.new(asset.source).result binding
  }
end


FixedGear::Renderers['.erb'] = FixedGear::ERB::Renderer
