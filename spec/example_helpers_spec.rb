require_relative "spec_helper"
require_relative "../lib/swagalicious/example_helpers"

describe Swagalicious::ExampleHelpers do
  subject { double("example") }

  before do
    subject.extend(described_class)

    allow(subject).to receive(:client).and_return(client)

    expect(subject).to receive(:client).and_return(client)

    allow(response).to receive(:body).and_return("")
    allow(response).to receive(:status).and_return(201)
    allow(response).to receive(:headers).and_return({ "ACCEPT" => "application/json" })

    allow(Swagalicious).to receive(:config).and_return(config)
    allow(config).to       receive(:get_swagger_doc).and_return(config.swagger_docs.values.first)
    allow(config).to       receive(:get_swagger_doc_version).and_return(config.swagger_docs.values.first[:openapi])

    allow(JSON::Validator).to receive(:fully_validate).and_return([])
  end

  let(:config)   { build(:config) }
  let(:client)   { double("Faraday") }
  let(:response) { double("Faraday::Response") }
  let(:metadata) { build(:metadata) }

  describe "#submit_request(metadata)" do
    before do
      allow(subject).to receive(:blog_id).and_return(1)
      allow(subject).to receive(:id).and_return(2)
      allow(subject).to receive(:q1).and_return("foo")
      allow(subject).to receive(:api_key).and_return("fookey")
      allow(subject).to receive(:blog).and_return(text: "Some comment")
    end

    it "submits a request built from metadata and 'let' values" do
      expect(client).to receive(:post).and_return(response)
      subject.submit_request(metadata)
    end
  end
end
