require "json"

class Swagalicious
  class UnexpectedResponse < StandardError; end

  class ResponseValidator
    def initialize(config = ::Swagalicious::config)
      @config = config
    end

    def validate!(metadata, response)
      swagger_doc = @config.get_swagger_doc(metadata[:swagger_doc])

      validate_code!(metadata, response.status)
      validate_headers!(metadata, response.headers)
      validate_body!(metadata, swagger_doc, response.body)
    end

    private

    def validate_code!(metadata, response)
      expected = metadata[:response][:code].to_s
      if response.to_s != expected.to_s
        raise UnexpectedResponse, "Expected response code '#{response}' to match '#{expected}'"
      end
    end

    def validate_headers!(metadata, headers)
      expected = (metadata[:response][:headers] || {}).keys
      expected.each do |name|
        raise UnexpectedResponse, "Expected response header #{name} to be present" if headers[name.to_s].nil?
      end
    end

    def validate_body!(metadata, swagger_doc, body)
      response_schema = metadata[:response][:schema]
      return if response_schema.nil?

      version = @config.get_swagger_doc_version(metadata[:swagger_doc])
      schemas = definitions_or_component_schemas(swagger_doc, version)

      validation_schema = response_schema
        .merge("$schema" => "http://tempuri.org/swagalicious/extended_schema")
        .merge(schemas)

      errors = JSON::Validator.fully_validate(validation_schema, body)
      raise UnexpectedResponse, "Expected response body to match schema: #{errors.join(", ")}" unless errors.empty?
    end

    def definitions_or_component_schemas(swagger_doc, version)
      if version.start_with?("2")
        swagger_doc.slice(:definitions)
      else # Openapi3
        if swagger_doc.key?(:definitions)
          @config.logger.warn "Swagger::Specs: WARNING: definitions is replaced in OpenAPI3! Rename to components/schemas (in swagger_helper.rb)"
          swagger_doc.slice(:definitions)
        else
          components = swagger_doc[:components] || {}
          { components: { schemas: components[:schemas] } }
        end
      end
    end
  end
end
