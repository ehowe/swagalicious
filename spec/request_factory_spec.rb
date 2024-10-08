require_relative "spec_helper"
require_relative "../lib/swagalicious/request_factory"

describe Swagalicious::RequestFactory do
  subject { described_class.new(config) }

  before do
    allow(config).to receive(:get_swagger_doc).and_return(swagger_doc)
  end
  let(:config)      { build(:config) }
  let(:swagger_doc) { { swagger: "3.0" } }
  let(:example)     { double("example") }
  let(:metadata) do
    {
      path_item: { template: "/blogs" },
      operation: { verb: :get }
    }
  end

  describe "#build_request(metadata, example)" do
    let(:request) { subject.build_request(metadata, example) }

    it "builds request hash for given example" do
      expect(request[:verb]).to eq(:get)
      expect(request[:path]).to eq("/blogs")
    end

    context "'path' parameters" do
      before do
        metadata[:path_item][:template]   = "/blogs/{blog_id}/comments/{id}"
        metadata[:operation][:parameters] = [
          { name: "blog_id", in: :path, type: :number },
          { name: "id", in: :path, type: :number }
        ]
        allow(example).to receive(:blog_id).and_return(1)
        allow(example).to receive(:id).and_return(2)
      end

      it "builds the path from example values" do
        expect(request[:path]).to eq("/blogs/1/comments/2")
      end
    end

    context "'query' parameters" do
      before do
        metadata[:operation][:parameters] = [
          { name: "q1", in: :query, schema: { type: :string } },
          { name: "q2", in: :query, schema: { type: :array, items: { type: :string } }, style: :form, explode: true },
        ]
        allow(example).to receive(:q1).and_return("foo")
        allow(example).to receive(:q2).and_return(%w(bar baz))
      end

      it "builds the query string from example values" do
        expect(request[:path]).to eq("/blogs?q1=foo&q2=bar&q2=baz")
      end
    end

    context "'query' parameters of type 'array'" do
      before do
        metadata[:operation][:parameters] = [
          { name: "things", in: :query, schema: { type: :array, items: { type: :string } }, style: style, explode: explode }
        ]
        allow(example).to receive(:things).and_return(["foo", "bar"])
      end

      context "style=form explode=false" do
        let(:style)   { :form }
        let(:explode) { false }

        it "formats as comma separated values" do
          expect(request[:path]).to eq("/blogs?things=foo,bar")
        end
      end

      context "style=form explode=true" do
        let(:style)   { :form }
        let(:explode) { true }

        it "formats as comma separated values" do
          expect(request[:path]).to eq("/blogs?things=foo&things=bar")
        end
      end

      context "style=spaceDelimited explode=false" do
        let(:style) { :spaceDelimited }
        let(:explode) { false }

        it "formats as space separated values" do
          expect(request[:path]).to eq("/blogs?things=foo bar")
        end
      end

      context "style=spaceDelimited explode=true" do
        let(:style) { :spaceDelimited }
        let(:explode) { true }

        it "formats as default" do
          expect(request[:path]).to eq("/blogs?things=foo&things=bar")
        end
      end

      context "style=pipeDelimited explode=false" do
        let(:style) { :pipeDelimited }
        let(:explode) { false }

        it "formats as pipe separated values" do
          expect(request[:path]).to eq("/blogs?things=foo|bar")
        end
      end

      context "style=pipeDelimited explode=true" do
        let(:style) { :pipeDelimited }
        let(:explode) { true }

        it "formats as default" do
          expect(request[:path]).to eq("/blogs?things=foo&things=bar")
        end
      end
    end

    context "'header' parameters" do
      before do
        metadata[:operation][:parameters] = [{ name: "Api-Key", in: :header, type: :string }]
        allow(example).to receive(:'Api-Key').and_return("foobar")
      end

      it "adds names and example values to headers" do
        expect(request[:headers]).to eq({ "Api-Key" => "foobar" })
      end
    end

    context "optional parameters not provided" do
      before do
        metadata[:operation][:parameters] = [
          { name: "q1", in: :query, type: :string, required: false },
          { name: "Api-Key", in: :header, type: :string, required: false }
        ]
      end

      it "builds request hash without them" do
        expect(request[:path]).to eq("/blogs")
        expect(request[:headers]).to eq({})
      end
    end

    context "consumes content" do
      before do
        metadata[:operation][:consumes] = ["application/json", "application/xml"]
      end

      context "no 'Content-Type' provided" do
        it "sets 'CONTENT_TYPE' header to first in list" do
          expect(request[:headers]).to eq("CONTENT_TYPE" => "application/json")
        end
      end

      context "explicit 'Content-Type' provided" do
        before do
          allow(example).to receive(:'Content-Type').and_return("application/xml")
        end

        it "sets 'CONTENT_TYPE' header to example value" do
          expect(request[:headers]).to eq("CONTENT_TYPE" => "application/xml")
        end
      end

      context "JSON payload" do
        before do
          metadata[:operation][:parameters] = [{ name: "comment", in: :body, schema: { type: "object" } }]
          allow(example).to receive(:comment).and_return(text: "Some comment")
        end

        it "serializes first 'body' parameter to JSON string" do
          expect(request[:payload]).to eq('{"text":"Some comment"}')
        end
      end

      context "form payload" do
        before do
          metadata[:operation][:consumes]   = ["multipart/form-data"]
          metadata[:operation][:parameters] = [
            { name: "f1", in: :formData, type: :string },
            { name: "f2", in: :formData, type: :string }
          ]
          allow(example).to receive(:f1).and_return("foo blah")
          allow(example).to receive(:f2).and_return("bar blah")
        end

        it "sets payload to hash of names and example values" do
          expect(request[:payload]).to eq(
            "f1" => "foo blah",
            "f2" => "bar blah"
          )
        end
      end
    end

    context "produces content" do
      before do
        metadata[:operation][:produces] = ["application/json", "application/xml"]
      end

      context "no 'Accept' value provided" do
        it "sets 'HTTP_ACCEPT' header to first in list" do
          expect(request[:headers]).to eq("HTTP_ACCEPT" => "application/json")
        end
      end

      context "explicit 'Accept' value provided" do
        before do
          allow(example).to receive(:Accept).and_return("application/xml")
        end

        it "sets 'HTTP_ACCEPT' header to example value" do
          expect(request[:headers]).to eq("HTTP_ACCEPT" => "application/xml")
        end
      end
    end

    context "basic auth" do
      context "openapi 3.0.1" do
        let(:swagger_doc) { { openapi: "3.0.1" } }

        before do
          swagger_doc[:components]        = { securitySchemes: { basic: { type: :basic } } }
          metadata[:operation][:security] = [basic: []]
          allow(example).to receive(:Authorization).and_return("Basic foobar")
        end

        it "sets 'HTTP_AUTHORIZATION' header to example value" do
          expect(request[:headers]).to eq("HTTP_AUTHORIZATION" => "Basic foobar")
        end
      end

      context "openapi 3.0.1 upgrade notice" do
        let(:swagger_doc) { { openapi: "3.0.1" } }

        before do
          swagger_doc[:securityDefinitions] = { basic: { type: :basic } }
          metadata[:operation][:security]   = [basic: []]
          allow(example).to receive(:Authorization).and_return("Basic foobar")
        end

        it "warns the user to upgrade" do
          expect(request[:headers]).to eq("HTTP_AUTHORIZATION" => "Basic foobar")
          expect(swagger_doc[:components]).to have_key(:securitySchemes)
        end
      end
    end

    context "apiKey" do
      let(:extra)        { { } }
      let(:key_location) { :header }

      before do
        swagger_doc[:components]                 ||= {}
        swagger_doc[:components][:securitySchemes] = { apiKey: { type: :apiKey, name: "api_key", in: key_location, **extra } }
        metadata[:operation][:security]            = [apiKey: []]
        allow(example).to receive(:api_key).and_return("foobar")
      end

      context "in query" do
        let(:key_location) { :query }

        it "adds name and example value to the query string" do
          expect(request[:path]).to eq("/blogs?api_key=foobar")
        end
      end

      context "in header" do
        it "adds name and example value to the headers" do
          expect(request[:headers]).to eq("api_key" => "foobar")
        end
      end

      context "in header with auth param already added" do
        before do
          metadata[:operation][:parameters] = [
            { name: "q1", in: :query, type: :string },
            { name: "api_key", in: :header, type: :string }
          ]
          allow(example).to receive(:q1).and_return("foo")
          allow(example).to receive(:api_key).and_return("foobar")
        end

        it "adds authorization parameter only once" do
          expect(request[:headers]).to eq("api_key" => "foobar")
          expect(metadata[:operation][:parameters].size).to eq 2
        end
      end

      context "in header with a forced header name" do
        let(:extra)      { { force_name: true, name: "ForcedName" } }

        before { allow(example).to receive(:ForcedName).and_return("ForcedValue") }

        it "sets the header to the correct name" do
          expect(request[:headers]).to eq("ForcedName" => "ForcedValue")
        end
      end
    end

    context "oauth2" do
      before do
        swagger_doc[:securityDefinitions] = { oauth2: { type: :oauth2, scopes: ["read:blogs"] } }
        metadata[:operation][:security]   = [oauth2: ["read:blogs"]]
        allow(example).to receive(:Authorization).and_return("Bearer foobar")
      end

      it "sets 'HTTP_AUTHORIZATION' header to example value" do
        expect(request[:headers]).to eq("HTTP_AUTHORIZATION" => "Bearer foobar")
      end
    end

    context "paired security requirements" do
      before do
        swagger_doc[:securityDefinitions] = {
          basic:   { type: :basic },
          api_key: { type: :apiKey, name: "api_key", in: :query }
        }
        metadata[:operation][:security]   = [{ basic: [], api_key: [] }]
        allow(example).to receive(:Authorization).and_return("Basic foobar")
        allow(example).to receive(:api_key).and_return("foobar")
      end

      it "sets both params to example values" do
        expect(request[:headers]).to eq("HTTP_AUTHORIZATION" => "Basic foobar")
        expect(request[:path]).to eq("/blogs?api_key=foobar")
      end
    end

    context "path-level parameters" do
      before do
        metadata[:operation][:parameters] = [{ name: "q1", in: :query, type: :string }]
        metadata[:path_item][:parameters] = [{ name: "q2", in: :query, type: :string }]
        allow(example).to receive(:q1).and_return("foo")
        allow(example).to receive(:q2).and_return("bar")
      end

      it "populates operation and path level parameters" do
        expect(request[:path]).to eq("/blogs?q1=foo&q2=bar")
      end
    end

    context "referenced parameters" do
      context "swagger 2.0" do
        before do
          swagger_doc[:parameters]          = { q1: { name: "q1", in: :query, type: :string } }
          metadata[:operation][:parameters] = [{ "$ref" => "#/parameters/q1" }]
          allow(example).to receive(:q1).and_return("foo")
        end

        it "uses the referenced metadata to build the request" do
          expect(request[:path]).to eq("/blogs?q1=foo")
        end
      end

      context "openapi 3.0.1" do
        let(:swagger_doc) { { openapi: "3.0.1" } }

        before do
          swagger_doc[:components]          = { parameters: { q1: { name: "q1", in: :query, type: :string } } }
          metadata[:operation][:parameters] = [{ "$ref" => "#/components/parameters/q1" }]
          allow(example).to receive(:q1).and_return("foo")
        end

        it "uses the referenced metadata to build the request" do
          expect(request[:path]).to eq("/blogs?q1=foo")
        end
      end

      context "openapi 3.0.1 upgrade notice" do
        let(:swagger_doc) { { openapi: "3.0.1" } }

        before do
          swagger_doc[:parameters]          = { q1: { name: "q1", in: :query, type: :string } }
          metadata[:operation][:parameters] = [{ "$ref" => "#/parameters/q1" }]
          allow(example).to receive(:q1).and_return("foo")
        end

        it "warns the user to upgrade" do
          expect(request[:path]).to eq("/blogs?q1=foo")
        end
      end
    end

    context "global basePath" do
      before { swagger_doc[:basePath] = "/api" }

      it "prepends to the path" do
        expect(request[:path]).to eq("/api/blogs")
      end
    end

    context "global consumes" do
      before { swagger_doc[:consumes] = ["application/xml"] }

      it "defaults 'CONTENT_TYPE' to global value(s)" do
        expect(request[:headers]).to eq("CONTENT_TYPE" => "application/xml")
      end
    end

    context "global security requirements" do
      before do
        swagger_doc[:securityDefinitions] = { apiKey: { type: :apiKey, name: "api_key", in: :query } }
        swagger_doc[:security]            = [apiKey: []]
        allow(example).to receive(:api_key).and_return("foobar")
      end

      it "applieds the scheme by default" do
        expect(request[:path]).to eq("/blogs?api_key=foobar")
      end
    end
  end
end
