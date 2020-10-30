require "json-schema"

class Swagalicious
  class ExtendedSchema < JSON::Schema::Draft4
    def initialize
      super
      @attributes["type"] = ExtendedTypeAttribute
      @uri                = URI.parse("http://tempuri.org/swagalicious/extended_schema")
      @names              = ["http://tempuri.org/swagalicious/extended_schema"]
    end
  end

  class ExtendedTypeAttribute < JSON::Schema::TypeV4Attribute
    def self.validate(current_schema, data, fragments, processor, validator, options={})
      return if data.nil? && current_schema.schema["null"] == true
      super
    end
  end

  JSON::Validator.register_validator(ExtendedSchema.new)
end
