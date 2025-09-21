source "https://rubygems.org"
ruby "3.3.3"

# Rails framework
gem "rails", "~> 7.1.5", ">= 7.1.5.2"

# Core Rails gems
gem "sprockets-rails"          # Asset pipeline
gem "sqlite3", ">= 1.4", group: [:development, :test]       # Database for development
gem "puma", ">= 5.0"          # Web server
gem "importmap-rails"         # JavaScript with ESM import maps
gem "turbo-rails"             # Hotwire SPA-like page accelerator
gem "stimulus-rails"          # Hotwire modest JavaScript framework
gem "jbuilder"                # Build JSON APIs
gem "bootsnap", require: false # Reduces boot times through caching

# Platform-specific gems
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Application-specific gems
gem "devise"                  # Authentication
gem "simple_form"             # Form helpers
gem "icalendar"              # Calendar functionality
gem "csv"                    # CSV processing

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails"           # Testing framework
  gem "factory_bot_rails"     # Test data factories
  gem "shoulda-matchers"      # Testing matchers
  gem "database_cleaner-active_record" # Database cleaning for tests
  gem "dotenv-rails"          # Environment variables
end

group :development do
  gem "web-console"           # Console on exceptions pages
  # gem "rack-mini-profiler"  # Speed badges (commented out)
  # gem "spring"              # Speed up commands (commented out)
  gem "sqlite3", ">= 1.4", group: [:development, :test]

end

group :test do
  gem "faker"                 # Generate fake data for tests
  gem "capybara"             # Integration testing
  gem "selenium-webdriver"   # Browser automation for tests
  gem 'rspec_junit_formatter'
  gem 'rails-controller-testing'
  gem "sqlite3", ">= 1.4", group: [:development, :test]



end

# Optional gems (commented out)
# gem "redis", ">= 4.0.1"
# gem "kredis"
# gem "bcrypt", "~> 3.1.7"
# gem "image_processing", "~> 1.2"
group :production do
  gem "pg", "~> 1.1"
end
