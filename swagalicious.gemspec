require_relative "lib/swagalicious/version"

Gem::Specification.new do |spec|
  spec.name          = "swagalicious"
  spec.version       = Swagalicious::VERSION
  spec.authors       = ["Eugene Howe"]
  spec.email         = ["eugene.howe@protonmail.com"]

  spec.summary               = %q{RSwag without Rails}
  spec.description           = %q{This gem is almost a straight copy and paste of https://github.com/rswag/rswag/tree/master/rswag-specs with the Rails specific code stripped out so it can be used in Rack applications that don't use Rails.}
  spec.homepage              = "https://github.com/ehowe/swagalicious"
  spec.license               = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-rack"
  spec.add_dependency "json-schema"
  spec.add_dependency "oj"
  spec.add_dependency "ox"
  spec.add_dependency "rack-test"
  spec.add_dependency "rspec", "~> 3"

  spec.add_development_dependency "rubocop", "~> 1.48.0"
  spec.add_development_dependency "rubocop-rspec", "~> 2.19.0"
  spec.add_development_dependency "factory_bot", "~> 6.1.0"
  spec.add_development_dependency "pry-byebug",  "~> 3.9.0"
end
