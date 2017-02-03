require 'pathname'
require 'fileutils'

class FixedGear::Site
  include FileUtils

  def initialize(root:, build_dir: nil, source_dir: nil)
    yield self if block_given?

    self.root ||= root
    self.root = Pathname(self.root.to_s).expand_path
    self.build_dir ||= build_dir || self.root.join('build')
    self.source_dir ||= source_dir || self.root.join('source')

    freeze
  end

  attr_accessor :root, :build_dir, :source_dir

  TEMPLATES = {
    Gemfile: <<~GEMFILE,
    source 'https://rubygems.org'
    gem 'fixed_gear'
    gem 'puma'
    GEMFILE

    'config.ru': <<~CONFIG_RU,
    require 'bundler/setup'
    require 'fixed_gear'
    use FixedGear::Server::Rack.for_dir(__dir__)
    CONFIG_RU
  }

  def install
    make_dir = -> dir do
      puts "Dir:  #{dir.to_s}"
      dir.exist? or dir.mkpath
    end
    write_file = -> file, contents do
      file = root.join(file.to_s)
      puts "File: #{file.to_s}"
      file.exist? or file.open('w').write(contents)
    end

    make_dir[root]
    make_dir[build_dir]
    make_dir[source_dir]

    TEMPLATES.each(&write_file)

    cd(root.to_s) { system 'bundle install' }
    puts "Done"
  end

  def deploy
    system <<-BASH
    #!/usr/bin/env bash

    function sync-bucket {
      bucket="$1"
      profile="net2b"
      aws --profile $profile s3 --region eu-central-1 sync build/ "s3://$bucket" --acl public-read || \
      echo "Install and configure aws-cli: brew install awscli; aws configure --profile $profile"
    }

    "$(dirname $0)/build" --verbose && sync-bucket www.buttmuscle.eu
    BASH
  end

  def to_app
    app = -> env { [404, {}, []] }
    Rack::Static.new(app, root: build_dir.to_s, urls: [""], index: 'index.html')
  end

  def logger
    FixedGear.logger
  end

end
