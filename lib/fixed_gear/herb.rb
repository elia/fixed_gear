require 'erb'

module FixedGear::HERB
  HTMLTransformer = -> input {
    context = input[:metadata][:context] || input[:environment].context_class.new(input)
    locals = input[:metadata][:locals] || {}
    bind = context.instance_eval { binding }
    locals.each { |name, value| bind.local_variable_set(name, value) }
    erb = ::ERB.new(input[:data])
    erb.filename = input[:filename]
    data = erb.result bind
    context.metadata.merge(data: data)
  }

  XMLTransformer = HTMLTransformer

  Renderer = -> context, asset, locals {
    transformer = case asset.content_type
    when 'text/xml' then XMLTransformer
    when 'text/html' then HTMLTransformer
    else HTMLTransformer
    end

    transformer.call(
      data: asset.source,
      filename: asset.filename,
      metadata: {
        context: context,
        locals: locals,
      }
    )[:data]
  }
end

Sprockets.register_mime_type 'text/erb', extensions: ['.herb']
Sprockets.register_mime_type 'text/html', extensions: ['.html']
Sprockets.register_mime_type 'text/xml', extensions: ['.xml', '.rss', '.atom']
Sprockets.register_transformer 'text/herb', 'text/html', FixedGear::HERB::HTMLTransformer
Sprockets.register_transformer 'text/herb', 'text/xml', FixedGear::HERB::XMLTransformer
FixedGear::Renderers['.herb'] = FixedGear::HERB::Renderer
