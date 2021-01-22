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
      expect(client).to receive(:post).and_return(response)

      subject.submit_request(metadata)
    end

    it "has the default example name" do
      expect(metadata[:response][:examples][metadata[:produces].first].keys.first).to eq("#{metadata[:operation][:summary]}: #{metadata[:description]}")
    end

    context "with a custom example name" do
      let(:metadata) { build(:metadata, swagger_example_name: "test_swagger_example") }

      it "has the custom example name" do
        expect(metadata[:response][:examples][metadata[:produces].first].keys.first).to eq("test_swagger_example")
      end
    end
  end
end
