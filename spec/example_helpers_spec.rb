require_relative "spec_helper"
require_relative "../lib/swagalicious/example_helpers"

describe Swagalicious::ExampleHelpers do
  subject { double("example") }

  before do
    subject.extend(described_class)

    allow(subject).to receive(:client).and_return(client)

    expect(subject).to receive(:client).and_return(client)

    allow(response).to receive(:body).and_return(body)
    allow(response).to receive(:status).and_return(status)
    allow(response).to receive(:headers).and_return({ "ACCEPT" => content_type, "Content-Type" => content_type })

    allow(Swagalicious).to receive(:config).and_return(config)
    allow(config).to       receive(:get_swagger_doc).and_return(config.swagger_docs.values.first)
    allow(config).to       receive(:get_swagger_doc_version).and_return(config.swagger_docs.values.first[:openapi])

    allow(JSON::Validator).to receive(:fully_validate).and_return([])
  end

  let(:body)         { "" }
  let(:config)       { build(:config) }
  let(:content_type) { "application/json" }
  let(:client)       { double("Faraday") }
  let(:response)     { double("Faraday::Response") }
  let(:metadata)     { build(:metadata, code: status.to_s) }
  let(:status)       { 201 }

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

    context "parsing" do
      shared_examples_for "parsing" do |description|
        it "matches the #{description} input" do
          expect(metadata[:response][:examples][metadata[:produces].first].values.first).to eq(parsed)
        end
      end

      it_behaves_like "parsing", "json" do
        let(:status) { 200 }
        let(:body)   { '{"test": "asdf"}' }
        let(:parsed) { Oj.load(body, symbol_keys: true) }
      end

      it_behaves_like "parsing", "yaml" do
        let(:content_type) { "application/yml" }
        let(:status) { 200 }
        let(:body)   { "---\ntest: asdf" }
        let(:parsed) { YAML.load(body).with_indifferent_access }
      end

      it_behaves_like "parsing", "xml" do
        let(:content_type) { "application/xml" }
        let(:status) { 200 }
        let(:body)   { "<test>asdf</test>" }
        let(:parsed) { Ox.load(body, mode: :hash_no_attrs).with_indifferent_access }
      end
    end
  end
end
