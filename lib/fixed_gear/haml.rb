require 'haml'

module FixedGear::Haml
  HTMLTransformer = -> input {
    context = input[:metadata][:context] || input[:environment].context_class.new(input)
    data = ::Haml::Engine
      .new(input[:data], filename: input[:filename], format: :html5)
      .render(context, input[:metadata][:locals] || {})
    context.metadata.merge(data: data)
  }

  XMLTransformer = -> input {
    context = input[:metadata][:context] || input[:environment].context_class.new(input)
    data = ::Haml::Engine
      .new(input[:data], filename: input[:filename], format: :xhtml)
      .render(context, input[:metadata][:locals] || {})
    context.metadata.merge(data: data)
  }

  Renderer = -> context, asset, locals {
    # p Renderer: asset.filename
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

Sprockets.register_mime_type 'text/haml', extensions: ['.haml']
Sprockets.register_mime_type 'text/html', extensions: ['.html']
Sprockets.register_mime_type 'text/xml', extensions: ['.xml', '.rss', '.atom']
Sprockets.register_transformer 'text/haml', 'text/html', FixedGear::Haml::HTMLTransformer
Sprockets.register_transformer 'text/haml', 'text/xml', FixedGear::Haml::XMLTransformer
FixedGear::Renderers['.haml'] = FixedGear::Haml::Renderer
