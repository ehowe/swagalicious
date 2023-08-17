require "faraday"
require "faraday/rack"
require "rack"
require "json"
require "oj"
require "ox"
require "yaml"
require "active_support/core_ext/hash/indifferent_access"

require_relative "response_validator"

class Swagalicious
  module ExampleHelpers
    include Rack::Test::Methods

    def self.raise_invalid_response(response:, request:, message:)
      raise InvalidResponseTypeError.new(
        headers: response.headers,
        message: message,
        request: request,
        response: response,
        status: response.status,
      )
    end

    class InvalidResponseTypeError < RuntimeError
      attr_reader :status, :_message, :headers, :response, :request

      def initialize(status:, message:, headers:, response:, request:)
        @headers  = headers
        @_message = message
        @request  = request
        @response = response
        @status   = status
      end

      def inspect
        JSON.pretty_generate(to_h)
      end

      def to_h
        hash = {
          headers: headers.to_h,
          message: _message,
          request: request.slice(:verb, :path, :headers),
          status:  status,
        }

        if parsed_body = Parser.new(request: request, response: response).parse(raise_on_invalid: false)
          hash[:parsed_response] = parsed_body
        end

        hash
      end

      def to_s
        "Received unexpected or unparseable response with status code #{status} for #{request[:verb].upcase} #{request[:path]}: #{_message}"
      end

      def message
        inspect
      end
    end

    class MockResponse
      attr_reader :body, :status, :headers

      def initialize(file_name)
        @body    = File.read(File.expand_path("#{File.join(ENV["MOCK_PATH"], file_name)}.json", __FILE__))
        @status  = 200
        @headers = {}
      end
    end

    class Parser
      attr_accessor :body
      attr_reader :content_type, :request, :response

      def initialize(response:, request:)
        @content_type = response.headers["Content-Type"]
        @body         = response.body
        @response     = response
        @request      = request
      end

      def parse(raise_on_invalid: true)
        # Redirections shouldnt be parsed
        if response.status >= 300 && response.status <= 399
          return
        end

        case content_type
        when /json/
          self.body = "{}" if self.body.empty?

          Oj.load(self.body, symbol_keys: true)
        when /ya?ml/
          body = "---" if self.body.empty?

          (YAML.load(self.body) || {}).with_indifferent_access
        when /xml/
          (Ox.load(self.body, mode: :hash_no_attrs) || {}).with_indifferent_access
        when "", nil, /html/
          self.body
        else
          return unless raise_on_invalid

          Swagalicious::ExampleHelpers.raise_invalid_response(response: response, request: request, message: "Invalid Content-Type header #{response.headers["Content-Type"]}")
        end
      end
    end

    def app
      @app ||= if defined?(Rails)
                 Rails.application
               elsif Rack::RELEASE >= "3.0.0"
                 Rack::Builder.parse_file("config.ru")
               else
                 Rack::Builder.parse_file("config.ru").first
               end
    end

    def client
      @client ||= Faraday.new do |b|
        b.adapter Faraday::Adapter::Rack, app
      end
    end

    def submit_request(metadata, mocked: false, mock_name: nil)
      request  = RequestFactory.new.build_request(metadata, self)
      uri      = URI.parse(request[:path])
      uri.path = uri.path.gsub("//", "/")

      response = if mocked
                   file_name = File.basename(mock_name || path)

                   MockResponse.new(file_name)
                 else
                   client.public_send(request[:verb]) do |req|
                     req.url uri.to_s
                     req.headers = request[:headers]
                     req.body    = request[:payload]
                   end
                 end

      Swagalicious::ExampleHelpers.raise_invalid_response(response: response, request: request, message: "Received unexpected response code") unless response.status.to_s == metadata[:response][:code].to_s

      @body = Parser.new(request: request, response: response).parse

      metadata[:paths] ||= []
      metadata[:paths] << request[:path]

      metadata[:response][:requestBody] ||= {}
      metadata[:response][:examples]    ||= {}

      mime_types = metadata[:response][:produces]  || ["application/json"]
      full_title = metadata[:swagger_example_name] || "#{metadata[:operation][:summary]}: #{metadata[:description]}"

      mime_types.each do |mime_type|
        if request[:payload]
          metadata[:response][:requestBody][:content]                                   ||= {}
          metadata[:response][:requestBody][:content][mime_type]                        ||= {}
          metadata[:response][:requestBody][:content][mime_type][:examples]             ||= {}
          metadata[:response][:requestBody][:content][mime_type][:examples][full_title] ||= {}

          metadata[:response][:requestBody][:content][mime_type][:examples][full_title][:value] = Oj.load(request[:payload]).dup
        end

        metadata[:response][:examples][mime_type]           ||= {}
        metadata[:response][:examples][mime_type][full_title] = @body
      end

      # Validates response matches the proper schema
      Swagalicious::ResponseValidator.new.validate!(metadata, response)

      response
    end
  end
end
