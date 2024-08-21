require_relative "spec_helper"

require_relative "../lib/swagalicious/response_validator"

describe Swagalicious::ResponseValidator do
  subject { described_class.new(config) }

  before do
    allow(config).to receive(:get_swagger_doc).and_return(swagger_doc)
    allow(config).to receive(:get_swagger_doc_version).and_return("3.0")
  end
  let(:config)      { build(:config) }
  let(:swagger_doc) { {} }
  let(:example)     { double("example") }
  let(:properties)  { { type: :string } }
  let(:metadata) do
    {
      response: {
        code:    200,
        headers: { "X-Rate-Limit-Limit" => { type: :integer } },
        schema:  {
          type:       :object,
          properties: { text: properties },
          required:   ["text"]
        }
      }
    }
  end

  describe "null" do
    context "with nullable" do
      let(:properties) { { type: :string, nullable: true } }
      let(:call)       { subject.validate!(metadata, response) }
      let(:response) do
        OpenStruct.new(
          status: "200",
          headers: { "X-Rate-Limit-Limit" => "10" },
          body: '{"text":null}'
        )
      end

      context "response matches metadata" do
        it { expect { call }.to_not raise_error }
      end
    end

    context "with null" do
      let(:properties) { { type: [:string, :null] } }
      let(:call)       { subject.validate!(metadata, response) }
      let(:response) do
        OpenStruct.new(
          status: "200",
          headers: { "X-Rate-Limit-Limit" => "10" },
          body: '{"text":null}'
        )
      end

      context "response matches metadata" do
        it { expect { call }.to_not raise_error }
      end
    end
  end

  describe "#validate!(metadata, response)" do
    let(:call) { subject.validate!(metadata, response) }
    let(:response) do
      OpenStruct.new(
        status: "200",
        headers: { "X-Rate-Limit-Limit" => "10" },
        body: '{"text":"Some comment"}'
      )
    end

    context "response matches metadata" do
      it { expect { call }.to_not raise_error }
    end

    context "response code differs from metadata" do
      before { response.status = "400" }
      it { expect { call }.to raise_error(/Expected response code/) }
    end

    context "response headers differ from metadata" do
      before { response.headers = {} }
      it { expect { call }.to raise_error(/Expected response header/) }
    end

    context "response body differs from metadata" do
      before { response.body = '{"foo":"Some comment"}' }
      it { expect { call }.to raise_error(/Expected response body/) }
    end

    context "referenced schemas" do
      context "openapi 3.0.1" do
        context "components/schemas" do
          before do
            allow(config).to receive(:get_swagger_doc_version).and_return("3.0.1")
            swagger_doc[:components]     = {
              schemas: {
                "blog" => {
                  type:       :object,
                  properties: { foo: { type: :string } },
                  required:   ["foo"]
                }
              }
            }
            metadata[:response][:schema] = { "$ref" => "#/components/schemas/blog" }
          end

          it "uses the referenced schema to validate the response body" do
            expect { call }.to raise_error(/Expected response body/)
          end
        end

        context "deprecated definitions" do
          before do
            allow(config).to receive(:get_swagger_doc_version).and_return("3.0.1")
            swagger_doc[:definitions]    = {
              "blog" => {
                type:       :object,
                properties: { foo: { type: :string } },
                required:   ["foo"]
              }
            }
            metadata[:response][:schema] = { "$ref" => "#/definitions/blog" }
          end

          it "warns the user to upgrade" do
            expect { call }.to raise_error(/Expected response body/)
          end
        end
      end
    end
  end
end
