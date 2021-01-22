FactoryBot.define do
  factory :group, class: OpenStruct do
  end

  factory :metadata, class: Hash do
    description  { "Description" }
     document    { nil }
     operation   { { verb: :post, summary: "Creates a blog", parameters: [{ type: :string }], produces: [ "application/json" ] } }
     path_item   { { template: "/blogs", parameters: [{ type: :string }] } }
     produces    { ["application/json"] }
     response    { { code: "201", description: "blog created", headers: { "ACCEPT" => "application/json" }, schema: { "$ref" => "#/definitions/blog" } } }
     swagger_doc { "test.json" }

     initialize_with { attributes }
  end

  factory :example, class: OpenStruct do
    metadata { build(:metadata) }
  end

  factory :notification, class: OpenStruct do
    group    { build(:group) }
    examples { [ build(:example) ] }
  end

  factory :config, class: OpenStruct do
    transient do
      file_name { "test-#{SecureRandom.hex(3)}.json" }
    end

    swagger_docs { {
      file_name => {
        openapi: "3.0.1"
      }
    } }

    swagger_root { File.expand_path("../tmp/swagger", __dir__) }
  end
end
