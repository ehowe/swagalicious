require "faraday"
require "faraday/rack"
require "rack"
require "oj"

require_relative "response_validator"

class Swagalicious
  module ExampleHelpers
    include Rack::Test::Methods

    class MockResponse
      attr_reader :body, :status, :headers

      def initialize(file_name)
        @body    = File.read(File.expand_path("#{File.join(ENV["MOCK_PATH"], file_name)}.json", __FILE__))
        @status  = 200
        @headers = {}
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

      body = response.body
      body = "{}" if body.empty?

      @body = Oj.load(body, symbol_keys: true)

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
