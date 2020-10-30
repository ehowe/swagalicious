require "faraday"
require "faraday/adapter/rack"
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
      @app ||= Rack::Builder.parse_file("config.ru").first
    end

    def client
      @client ||= Faraday.new do |b|
        b.adapter Faraday::Adapter::Rack, app
      end
    end

    def submit_request(metadata, mocked: false, mock_name: nil)
      request = RequestFactory.new.build_request(metadata, self)

      response = if mocked
                   file_name = File.basename(mock_name || URI.parse(request[:path]).path)

                   MockResponse.new(file_name)
                 else
                   client.public_send(request[:verb]) do |req|
                     req.url request[:path].gsub("//", "/")
                     req.headers = request[:headers]
                     req.body    = request[:payload]
                   end
                 end

      body = response.body
      body = "{}" if body.empty?

      @body = Oj.load(body, symbol_keys: true)

      if request[:payload]
        metadata[:response][:request] = Oj.load(request[:payload])
      end

      metadata[:response][:examples]                   ||= {}
      metadata[:response][:examples]["application/json"] = @body

      # Validates response matches the proper schema
      Swagalicious::ResponseValidator.new.validate!(metadata, response)

      response
    end
  end
end
