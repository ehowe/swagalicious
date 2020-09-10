require_relative "spec_helper"
require_relative "../lib/swagalicious/example_helpers"

describe Swagalicious::ExampleHelpers do
  subject { double("example") }

  before do
    subject.extend(described_class)

    allow(subject).to receive(:client).and_return(client)

    expect(subject).to receive(:client).and_return(client)

    allow(response).to receive(:body).and_return("")
    allow(response).to receive(:status).and_return(200)
    allow(response).to receive(:headers).and_return({})

    allow(Swagalicious).to receive(:config).and_return(config)
    allow(config).to       receive(:get_swagger_doc).and_return(swagger_doc)
  end

  let(:config)   { double("config") }
  let(:client)   { double("Faraday") }
  let(:response) { double("Faraday::Response") }

  let(:swagger_doc) do
    {
      swagger:             "3.0",
      securityDefinitions: {
        api_key: {
          type: :apiKey,
          name: "api_key",
          in:   :query
        }
      }
    }
  end

  let(:metadata) do
    {
      path_item: { template: "/blogs/{blog_id}/comments/{id}" },
      response:  { code: 200 },
      operation: {
        verb:       :put,
        summary:    "Updates a blog",
        consumes:   ["application/json"],
        parameters: [
          { name: :blog_id, in: :path, type: "integer" },
          { name: "id", in: :path, type: "integer" },
          { name: "q1", in: :query, type: "string" },
          { name: :blog, in: :body, schema: { type: "object" } }
        ],
        security:   [
          { api_key: [] }
        ]
      },
    }
  end

  describe "#submit_request(metadata)" do
    before do
      allow(subject).to receive(:blog_id).and_return(1)
      allow(subject).to receive(:id).and_return(2)
      allow(subject).to receive(:q1).and_return("foo")
      allow(subject).to receive(:api_key).and_return("fookey")
      allow(subject).to receive(:blog).and_return(text: "Some comment")
    end

    it "submits a request built from metadata and 'let' values" do
      expect(client).to receive(:put).and_return(response)
      subject.submit_request(metadata)
    end
  end
end
