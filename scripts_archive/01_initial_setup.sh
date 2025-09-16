#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 1: Initial Rails setup"

if ! command -v ruby >/dev/null 2>&1; then
    echo "Ruby not found. Please install Ruby first"
    exit 1
fi

if ! command -v rails >/dev/null 2>&1; then
    gem install rails
fi

rm -rf "$APP_NAME"
rails new $APP_NAME -d sqlite3 --skip-test
cd $APP_NAME

cat >> Gemfile << 'EOF'

gem 'devise'
gem 'simple_form'
gem 'icalendar'
EOF

bundle install
echo "✓ Initial Rails setup completed"
