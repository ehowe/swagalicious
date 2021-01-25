# frozen_string_literal: true

require_relative "../core/ext/hash"

class Swagalicious
  class SwaggerFormatter
    RSpec::Core::Formatters.register self, :stop

    def config
      @config ||= Swagalicious.config
    end

    def initialize(output, config = nil)
      @output = output
      @config = config

      @output.puts "Generating Swagger docs ..."
    end

    def merge_metadata_to_document(doc, example)
       metadata = example.metadata
       # !metadata[:document] won"t work, since nil means we should generate
       # docs.
       return {} if metadata[:document] == false
       return {} unless metadata.key?(:response)
       # This is called multiple times per file!
       # metadata[:operation] is also re-used between examples within file
       # therefore be careful NOT to modify its content here.
       upgrade_servers!(doc)
       upgrade_oauth!(doc)
       upgrade_response_produces!(doc, metadata)
       upgrade_request_type!(metadata)

       unless doc_version(doc).start_with?("2")
         doc[:paths]&.each_pair do |_k, v|
           v.each_pair do |_verb, value|
             is_hash = value.is_a?(Hash)
             if is_hash && value.dig(:parameters)
               schema_param = value.dig(:parameters)&.find { |p| (p[:in] == :body || p[:in] == :formData) && p[:schema] }
               mime_list    = value.dig(:consumes)
               if value && schema_param && mime_list
                 value[:requestBody] = { content: {} } unless value.dig(:requestBody, :content)
                 mime_list.each do |mime|
                   value[:requestBody][:content][mime] = { schema: schema_param[:schema] }
                 end
               end

               value[:parameters].reject! { |p| p[:in] == :body || p[:in] == :formData }
             end
             remove_invalid_operation_keys!(value)
           end
         end
       end

       doc.deep_merge!(metadata_to_swagger(metadata))
    end

    def stop(notification = nil)
      config.swagger_docs.each do |url_path, doc|
        examples = notification.examples.select { |e| e.metadata[:swagger_doc] == url_path }

        merged_doc = examples.each_with_object(doc) { |e, doc| doc = doc.deep_merge!(merge_metadata_to_document(doc, e)) }

        file_path = File.join(config.swagger_root, url_path)
        dirname   = File.dirname(file_path)
        FileUtils.mkdir_p dirname unless File.exist?(dirname)

        File.open(file_path, "w") do |file|
          file.write(pretty_generate(merged_doc))
        end

        @output.puts "Swagger doc generated at #{file_path}"
      end
    end

    private

    def pretty_generate(doc)
      if config.swagger_format == :yaml
        clean_doc = yaml_prepare(doc)
        YAML.dump(clean_doc)
      else # config errors are thrown in "def swagger_format", no throw needed here
        JSON.pretty_generate(doc)
      end
    end

    def yaml_prepare(doc)
      json_doc = JSON.pretty_generate(doc)
      JSON.parse(json_doc)
    end

    def metadata_to_swagger(metadata)
      response_code = metadata[:response][:code]
      response      = metadata[:response].reject { |k, _v| k == :code }
      examples      = response.delete(:examples) || []

      examples.each do |mime_type, titles|
        titles.each do |title, example|
          next unless response[:content][mime_type]

          response[:content][mime_type][:examples] ||= {}

          response[:content][mime_type][:examples][title] ||= {}

          response[:content][mime_type][:examples][title][:value] = example
        end
      end

      verb      = metadata[:operation][:verb]
      operation = metadata[:operation]
        .reject { |k, _v| k == :verb }
        .merge(responses: { response_code => response })

      path_template = metadata[:path_item][:template]
      path_item     = metadata[:path_item]
        .reject { |k, _v| k == :template }
        .merge(verb => operation)

      { paths: { path_template => path_item } }
    end

    def doc_version(doc)
      doc[:openapi] || doc[:swagger] || "3.0.0"
    end

    def upgrade_response_produces!(swagger_doc, metadata)
      # Accept header
      mime_list   = Array(metadata[:operation].delete(:produces) || swagger_doc[:produces])
      target_node = metadata[:response]
      upgrade_content!(mime_list, target_node)
      metadata[:response].delete(:schema)
    end

    def upgrade_content!(mime_list, target_node)
      target_node.merge!(content: {})
      schema = target_node[:schema]
      return if mime_list.empty? || schema.nil?

      mime_list.each do |mime_type|
        # TODO upgrade to have content-type specific schema
        body = target_node
          .fetch(:body, {})
          .fetch(mime_type, {})

        target_node[:content][mime_type] = { schema: schema }.merge(body)
      end
    end

    def upgrade_request_type!(metadata)
      # No deprecation here as it seems valid to allow type as a shorthand
      operation_nodes = metadata[:operation][:parameters] || []
      path_nodes      = metadata[:path_item][:parameters] || []
      header_node     = metadata[:response][:headers] || {}

      (operation_nodes + path_nodes + [header_node]).each do |node|
        if node && node[:type] && node[:schema].nil?
          node[:schema] = { type: node[:type] }
          node.delete(:type)
        end
      end
    end

    def upgrade_servers!(swagger_doc)
      return unless swagger_doc[:servers].nil? && swagger_doc.key?(:schemes)

      puts "Swagalicious: WARNING: schemes, host, and basePath are replaced in OpenAPI3! Rename to array of servers[{url}] (in swagger_helper.rb)"

      swagger_doc[:servers] = { urls: [] }
      swagger_doc[:schemes].each do |scheme|
        swagger_doc[:servers][:urls] << scheme + "://" + swagger_doc[:host] + swagger_doc[:basePath]
      end

      swagger_doc.delete(:schemes)
      swagger_doc.delete(:host)
      swagger_doc.delete(:basePath)
    end

    def upgrade_oauth!(swagger_doc)
      # find flow in securitySchemes (securityDefinitions will have been re-written)
      schemes = swagger_doc.dig(:components, :securitySchemes)
      return unless schemes&.any? { |_k, v| v.key?(:flow) }

      schemes.each do |name, v|
        next unless v.key?(:flow)

        puts "Swagalicious: WARNING: securityDefinitions flow is replaced in OpenAPI3! Rename to components/securitySchemes/#{name}/flows[] (in swagger_helper.rb)"

        flow = swagger_doc[:components][:securitySchemes][name].delete(:flow).to_s

        if flow == "accessCode"
          puts "Swagalicious: WARNING: securityDefinitions accessCode is replaced in OpenAPI3! Rename to clientCredentials (in swagger_helper.rb)"
          flow = "authorizationCode"
        end

        if flow == "application"
          puts "Swagalicious: WARNING: securityDefinitions application is replaced in OpenAPI3! Rename to authorizationCode (in swagger_helper.rb)"
          flow = "clientCredentials"
        end

        flow_elements = swagger_doc[:components][:securitySchemes][name].except(:type).each_with_object({}) do |(k, _v), a|
          a[k] = swagger_doc[:components][:securitySchemes][name].delete(k)
        end

        swagger_doc[:components][:securitySchemes][name].merge!(flows: { flow => flow_elements })
      end
    end

    def remove_invalid_operation_keys!(value)
      is_hash = value.is_a?(Hash)
      value.delete(:consumes) if is_hash && value.dig(:consumes)
      value.delete(:produces) if is_hash && value.dig(:produces)
    end
  end
end
