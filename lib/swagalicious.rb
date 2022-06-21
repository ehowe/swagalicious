require "rspec/core"

require_relative "./swagalicious/version"

begin
  require "rspec/rails"
rescue nil
end

class Swagalicious
  class Error < StandardError; end

  def self.config
    @config ||= Swagalicious::Configuration.new(RSpec.configuration)
  end

  require_relative "./swagalicious/configuration"
  require_relative "./swagalicious/example_group_helpers"
  require_relative "./swagalicious/example_helpers"
  require_relative "./swagalicious/extended_schema"
  require_relative "./swagalicious/request_factory"
  require_relative "./swagalicious/response_validator"
  require_relative "./swagalicious/swagger_formatter"

  ::RSpec::Core::ExampleGroup.define_example_group_method :path

  ::RSpec.configure do |c|
    c.add_setting :swagger_format
    c.add_setting :swagger_root
    c.add_setting :swagger_docs
    c.add_setting :swagger_dry_run

    if defined?(Rails) && defined?(RSpec::Rails)
      c.include RSpec::Rails::RequestExampleGroup, type: :doc
    end

    c.extend Swagalicious::ExampleGroupHelpers, type: :doc
    c.include Swagalicious::ExampleHelpers, type: :doc
  end
end
