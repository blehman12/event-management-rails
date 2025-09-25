# Gemfile
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.3"

gem "rails", "~> 7.1.5"
gem "sprockets-rails", ">= 2.0.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "redis", ">= 4.0.1"
gem "bootsnap", require: false
gem "sassc-rails"
gem "image_processing", "~> 1.2"


# Authentication & Authorization
gem "devise"

# Pagination
gem "kaminari"

# UI
gem "bootstrap", "~> 5.3"
gem 'simple_form'


# Add to your Gemfile:
group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
  gem "sqlite3", "~> 1.4"
  gem "capybara"
  gem "selenium-webdriver"
  gem "database_cleaner-active_record"  # Add this
  gem "rails-controller-testing"  # Add this
  gem "dotenv-rails"
  gem 'faker'

end

group :development do
  gem "web-console"
end

group :production do
  # Add production-specific gems here if needed
end
