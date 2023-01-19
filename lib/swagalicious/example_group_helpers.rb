class Swagalicious
  module ExampleGroupHelpers
    def path(template, metadata={}, &block)
      metadata[:path_item] = { template: template }
      describe(template, metadata, &block)
    end

    [ :get, :post, :patch, :put, :delete, :head ].each do |verb|
      define_method(verb) do |summary, &block|
        api_metadata = { operation: { verb: verb, summary: summary } }
        describe(verb, api_metadata, &block)
      end
    end

    [ :operationId, :deprecated, :security ].each do |attr_name|
      define_method(attr_name) do |value|
        metadata[:operation][attr_name] = value
      end
    end

    # NOTE: 'description' requires special treatment because ExampleGroup already
    # defines a method with that name. Provide an override that supports the existing
    # functionality while also setting the appropriate metadata if applicable
    def description(value=nil)
      return super() if value.nil?
      metadata[:operation][:description] = value
    end

    # These are array properties - note the splat operator
    [ :tags, :consumes, :produces, :schemes ].each do |attr_name|
      define_method(attr_name) do |*value|
        metadata[:operation][attr_name] = value
      end
    end

    def parameter(attributes)
      if attributes[:in] && attributes[:in].to_sym == :path
        attributes[:required] = true
      end

      if metadata.has_key?(:operation)
        metadata[:operation][:parameters] ||= []
        metadata[:operation][:parameters] << attributes
      else
        metadata[:path_item][:parameters] ||= []
        metadata[:path_item][:parameters] << attributes
      end
    end

    def response(code, description, metadata={}, &block)
      metadata[:response] = { code: code, description: description }
      context(description, metadata, &block)
    end

    def schema(value)
      metadata[:response][:schema] = value
    end

    def header(name, attributes)
      header_name = attributes.delete(:variable) || name

      metadata[:response][:headers]            ||= {}
      metadata[:response][:headers][header_name] = attributes
    end

    # NOTE: Similar to 'description', 'examples' need to handle the case when
    # being invoked with no params to avoid overriding 'examples' method of
    # rspec-core ExampleGroup
    def examples(example = nil)
      return super() if example.nil?
      metadata[:response][:examples] = example
    end

    def validate_schema!(mocked: false, mock_name: nil)
      it "returns a #{metadata[:response][:code]} response" do |example|
        yield if block_given?
        submit_request(example.metadata, mocked: mocked, mock_name: mock_name)
      end
    end
  end
end
