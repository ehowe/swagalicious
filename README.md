# Swagalicious

This gem is an implementation of https://github.com/rswag/rswag/blob/master/rswag-specs that does not rely on Rails. Most of the code is a blatant copy/paste from that repo, most of the credit goes to them.

Currenty it does not implement any API or UI. In the application that is using this gem, we are using https://github.com/Redocly/redoc that is accessed through a rack middleware.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'swagalicious'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install swagalicious

## Usage

Add the following to your `spec_helper.rb` or add a new `swagger_helper.rb`

```ruby
require 'swagalicious`

DEFINITIONS = Oj.load(File.read(File.expand_path("docs/definitions.json", __dir__))).freeze

RSpec.configure do |c|
  c.swagger_root = "public/swagger_docs" # This is the relative path where the swagger docs will be output
  c.swagger_docs = {
    "path/to/swagger_doc.json" => {
      swagger:  "3.0",
      basePath: "/api/",
      version:  "v1",
      info:     {
        title: "Namespace for my API"
      },
      components: {
        securitySchemes: {
          apiKey: {
            type: :apiKey,
            name: "authorization",
            in:   :header,
          }
        }
      },
    }
  }
end
```



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/eugene@xtreme-computers.net/swagalicious.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
