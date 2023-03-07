require_relative "spec_helper"

require_relative "../lib/swagalicious/swagger_formatter"

describe Swagalicious::SwaggerFormatter do
  let(:formatter) { described_class.new(output, config) }

  # Mock out some infrastructure
  before do
    FileUtils.rm_r(File.join(swagger_root, output_file)) if File.exist?(File.join(swagger_root, output_file))
  end

  let(:config)       { build(:config) }
  let(:output)       { double("output").as_null_object }
  let(:swagger_root) { config.swagger_root }
  let(:swagger_doc)  { config.swagger_docs.values.first }
  let(:output_file)  { config.swagger_docs.keys.first }

  describe "#stop(notification)" do
    subject { formatter.stop(notification) }

    let(:notification) { build(:notification) }

    context "with the document tag set to false" do
      let(:document) { false }

      it "does not update the swagger doc" do
        expect(swagger_doc).to match({ openapi: "3.0.1" })
      end
    end

    context "with metadata upgrades for 3.0" do
      let(:swagger_doc) do
        {
          "test.json" => {
            openapi:    "3.0.1",
            produces:   ["application/vnd.my_mime", "application/json"],
            servers:    { urls: [ "http://api.example.com/foo", "https://api.example.com/foo" ] },
            components: {
              securitySchemes: {
                myClientCredentials: {
                  type:      :oauth2,
                  flow:      :application,
                  token_url: :somewhere
                },
                myAuthorizationCode: {
                  type:      :oauth2,
                  flow:      :accessCode,
                  token_url: :somewhere
                },
                myImplicit:          {
                  type:      :oauth2,
                  flow:      :implicit,
                  token_url: :somewhere
                }
              }
            }
          }
        }
      end

      let(:config)   { build(:config, swagger_docs: swagger_doc) }
      let(:document) { nil }

      it "converts basePath, schemas and host to urls" do
        expect(subject.values.first.slice(:servers)).to match(
          servers: {
            urls: ["http://api.example.com/foo", "https://api.example.com/foo"]
          }
        )
      end

      it "upgrades oauth flow to flows" do
        expect(subject.values.first.slice(:components)).to match(
          components: {
            securitySchemes: {
              myClientCredentials: {
                type:  :oauth2,
                flows: {
                  "clientCredentials" => {
                    token_url: :somewhere
                  }
                }
              },
              myAuthorizationCode: {
                type:  :oauth2,
                flows: {
                  "authorizationCode" => {
                    token_url: :somewhere
                  }
                }
              },
              myImplicit:          {
                type:  :oauth2,
                flows: {
                  "implicit" => {
                    token_url: :somewhere
                  }
                }
              }
            }
          }
        )
      end
    end

    context "with default format" do
      before(:each) { subject }

      it "writes the swagger_doc(s) to file" do
        expect(File).to exist("#{swagger_root}/#{output_file}")
        expect { JSON.parse(File.read("#{swagger_root}/#{output_file}")) }.not_to raise_error
      end
    end

    context "with yaml format" do
      before(:each) do
        expect(config).to receive(:swagger_format).and_return(:yaml)

        subject
      end

      let(:swagger_format) { :yaml }

      it "writes the swagger_doc(s) as yaml" do
        expect(File).to exist("#{swagger_root}/#{output_file}")
        expect { JSON.parse(File.read("#{swagger_root}/#{output_file}")) }.to raise_error(JSON::ParserError)
        # Psych::DisallowedClass would be raised if we do not pre-process ruby symbols
        expect { YAML.safe_load(File.read("#{swagger_root}/#{output_file}")) }.not_to raise_error
      end
    end
  end
end
