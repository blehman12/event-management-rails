#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Setting up production deployment configuration..."

cd "$APP_NAME"

# Add production gems
cat >> Gemfile << 'PROD_GEMS_EOF'

# Production and deployment
group :production do
  gem 'pg', '~> 1.1'
  gem 'redis', '~> 4.0'
  gem 'puma', '~> 5.0'
  gem 'bootsnap', '>= 1.4.4', require: false
  gem 'image_processing', '~> 1.2'
end

# Deployment
gem 'capistrano', '~> 3.17', group: :development
gem 'capistrano-rails', '~> 1.6', group: :development
gem 'capistrano-passenger', '~> 0.2.1', group: :development
gem 'capistrano-rbenv', '~> 2.2', group: :development
PROD_GEMS_EOF

# Create production database configuration
cat >> config/database.yml << 'PROD_DB_EOF'

production:
  <<: *default
  adapter: postgresql
  database: <%= ENV['DATABASE_NAME'] || 'ptc_windchill_event_production' %>
  username: <%= ENV['DATABASE_USERNAME'] || 'ptc_app' %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] || 'localhost' %>
  port: <%= ENV['DATABASE_PORT'] || 5432 %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
PROD_DB_EOF

# Create production environment configuration
cat > config/environments/production.rb << 'PROD_ENV_EOF'
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.compile = false
  config.active_storage.variant_processor = :mini_magick
  config.log_level = :info
  config.log_tags = [ :request_id ]
  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.deprecation = :notify
  config.log_formatter = ::Logger::Formatter.new

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  config.active_record.dump_schema_after_migration = false

  # Force SSL
  config.force_ssl = true

  # Email configuration
  config.action_mailer.default_url_options = { 
    host: ENV['DOMAIN'] || 'ptcwindchill-events.com',
    protocol: 'https'
  }
  
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:         ENV['SMTP_SERVER'] || 'smtp.sendgrid.net',
    port:            ENV['SMTP_PORT'] || 587,
    domain:          ENV['DOMAIN'] || 'ptcwindchill-events.com',
    user_name:       ENV['SMTP_USERNAME'],
    password:        ENV['SMTP_PASSWORD'],
    authentication:  'plain',
    enable_starttls_auto: true
  }

  # Redis configuration for Sidekiq
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
  
  # Security headers
  config.force_ssl = true
  config.ssl_options = { hsts: { expires: 1.year, preload: true } }
end
PROD_ENV_EOF

# Create application secrets configuration
cat > config/credentials.yml.enc.example << 'CREDENTIALS_EOF'
# Use rails credentials:edit to set these values in production

secret_key_base: your_secret_key_base_here

# Database
database:
  username: ptc_app
  password: secure_database_password

# Email
smtp:
  username: your_smtp_username
  password: your_smtp_password
  server: smtp.sendgrid.net

# External services
redis_url: redis://localhost:6379/1
domain: ptcwindchill-events.com
CREDENTIALS_EOF

# Create deployment script
cat > bin/deploy << 'DEPLOY_SCRIPT_EOF'
#!/bin/bash
set -e

echo "=== PTC Windchill Event Deployment ==="

# Check environment
if [ "$1" != "production" ] && [ "$1" != "staging" ]; then
    echo "Usage: $0 [production|staging]"
    exit 1
fi

ENVIRONMENT=$1
echo "Deploying to: $ENVIRONMENT"

# Pre-deployment checks
echo "Running pre-deployment checks..."

# Check if all required environment variables are set
required_vars=(
    "SECRET_KEY_BASE"
    "DATABASE_NAME"
    "DATABASE_USERNAME"
    "DATABASE_PASSWORD"
    "SMTP_USERNAME"
    "SMTP_PASSWORD"
    "DOMAIN"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Environment variable $var is not set"
        exit 1
    fi
done

# Run tests
echo "Running test suite..."
RAILS_ENV=test rails db:create db:migrate
bundle exec rspec

# Asset precompilation
echo "Precompiling assets..."
RAILS_ENV=production rails assets:precompile

# Database operations
echo "Running database migrations..."
RAILS_ENV=production rails db:migrate

# Clear cache
echo "Clearing cache..."
RAILS_ENV=production rails tmp:cache:clear

# Restart application server
echo "Restarting application..."
if command -v passenger-config &> /dev/null; then
    passenger-config restart-app
elif command -v systemctl &> /dev/null; then
    sudo systemctl restart puma
fi

echo "Deployment completed successfully!"
echo "Application should be available at: https://$DOMAIN"
DEPLOY_SCRIPT_EOF

chmod +x bin/deploy

# Create monitoring script
cat > bin/health_check << 'HEALTH_SCRIPT_EOF'
#!/bin/bash

echo "=== Health Check for PTC Windchill Event ==="

# Check database connectivity
echo "Checking database connection..."
if rails runner "ActiveRecord::Base.connection" > /dev/null 2>&1; then
    echo "✓ Database: Connected"
else
    echo "✗ Database: Connection failed"
    exit 1
fi

# Check Redis connectivity (if using Sidekiq)
if command -v redis-cli &> /dev/null; then
    echo "Checking Redis connection..."
    if redis-cli ping > /dev/null 2>&1; then
        echo "✓ Redis: Connected"
    else
        echo "✗ Redis: Connection failed"
        exit 1
    fi
fi

# Check application response
echo "Checking application response..."
if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "✓ Application: Responding"
else
    echo "✗ Application: Not responding"
    exit 1
fi

echo "All health checks passed!"
HEALTH_SCRIPT_EOF

chmod +x bin/health_check

# Create health check endpoint
cat > app/controllers/health_controller.rb << 'HEALTH_CONTROLLER_EOF'
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    checks = {
      database: database_check,
      redis: redis_check,
      timestamp: Time.current.iso8601
    }

    if checks.values.all?
      render json: { status: 'healthy', checks: checks }, status: :ok
    else
      render json: { status: 'unhealthy', checks: checks }, status: :service_unavailable
    end
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue
    false
  end

  def redis_check
    return true unless defined?(Redis)
    Redis.new.ping == 'PONG'
  rescue
    false
  end
end
HEALTH_CONTROLLER_EOF

# Add health check route
sed -i '/root/a\  get "health", to: "health#show"' config/routes.rb

# Create systemd service file
cat > config/deploy/puma.service << 'SYSTEMD_EOF'
[Unit]
Description=Puma HTTP Server for PTC Windchill Event
After=network.target

[Service]
Type=notify
User=deploy
WorkingDirectory=/var/www/ptc_windchill_event/current
ExecStart=/home/deploy/.rbenv/bin/rbenv exec bundle exec puma -C /var/www/ptc_windchill_event/current/config/puma.rb
Restart=always
RestartSec=1
SyslogIdentifier=puma
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=5
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/ptc_windchill_event/.env

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Create nginx configuration
cat > config/deploy/nginx.conf << 'NGINX_EOF'
upstream puma_ptc_windchill_event {
  server unix:///var/www/ptc_windchill_event/shared/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name ptcwindchill-events.com www.ptcwindchill-events.com;
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ptcwindchill-events.com www.ptcwindchill-events.com;

  root /var/www/ptc_windchill_event/current/public;
  access_log /var/www/ptc_windchill_event/current/log/nginx.access.log;
  error_log /var/www/ptc_windchill_event/current/log/nginx.error.log info;

  # SSL Configuration
  ssl_certificate /etc/letsencrypt/live/ptcwindchill-events.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/ptcwindchill-events.com/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
  ssl_prefer_server_ciphers off;
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 10m;

  # Security headers
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;
  add_header X-XSS-Protection "1; mode=block";
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";

  # Gzip compression
  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_types text/css text/javascript application/javascript application/json;

  location ^~ /assets/ {
    gzip_static on;
    expires 1y;
    add_header Cache-Control public;
    add_header ETag "";
    break;
  }

  try_files $uri/index.html $uri @puma_ptc_windchill_event;

  location @puma_ptc_windchill_event {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://puma_ptc_windchill_event;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 10M;
  keepalive_timeout 10;
}
NGINX_EOF

# Create backup script
cat > bin/backup << 'BACKUP_SCRIPT_EOF'
#!/bin/bash
set -e

BACKUP_DIR="/var/backups/ptc_windchill_event"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="${DATABASE_NAME:-ptc_windchill_event_production}"

echo "=== Backup Process Started ==="
echo "Date: $(date)"
echo "Database: $DB_NAME"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Database backup
echo "Backing up database..."
pg_dump "$DB_NAME" | gzip > "$BACKUP_DIR/database_$DATE.sql.gz"

# Application files backup
echo "Backing up application files..."
tar -czf "$BACKUP_DIR/uploads_$DATE.tar.gz" -C /var/www/ptc_windchill_event/shared public/uploads 2>/dev/null || true

# Log files backup
echo "Backing up logs..."
tar -czf "$BACKUP_DIR/logs_$DATE.tar.gz" -C /var/www/ptc_windchill_event/current log/

# Cleanup old backups (keep 30 days)
echo "Cleaning up old backups..."
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR"
echo "Files created:"
ls -la "$BACKUP_DIR"/*"$DATE"*
BACKUP_SCRIPT_EOF

chmod +x bin/backup

# Create monitoring and alerting script
cat > bin/monitor << 'MONITOR_SCRIPT_EOF'
#!/bin/bash

LOG_FILE="/var/log/ptc_windchill_event_monitor.log"
ALERT_EMAIL="${ALERT_EMAIL:-admin@ptc.com}"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local subject="$1"
    local message="$2"
    
    # Send email alert (requires mail command)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "PTC Event App Alert: $subject" "$ALERT_EMAIL"
    fi
    
    log_message "ALERT: $subject - $message"
}

# Check disk space
check_disk_space() {
    local usage=$(df /var/www | awk 'NR==2 {print $(NF-1)}' | sed 's/%//')
    if [ "$usage" -gt 80 ]; then
        send_alert "High Disk Usage" "Disk usage is at ${usage}%"
    fi
}

# Check application response time
check_response_time() {
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' https://ptcwindchill-events.com/health || echo "999")
    local threshold=5  # 5 seconds
    
    if (( $(echo "$response_time > $threshold" | bc -l) )); then
        send_alert "Slow Response" "Application response time: ${response_time}s"
    fi
}

# Check database connections
check_database() {
    local connections=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='$DATABASE_NAME';" || echo "0")
    local max_connections=100
    
    if [ "$connections" -gt "$((max_connections * 80 / 100))" ]; then
        send_alert "High DB Connections" "Database connections: $connections/$max_connections"
    fi
}

# Check memory usage
check_memory() {
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        send_alert "High Memory Usage" "Memory usage is at ${memory_usage}%"
    fi
}

log_message "Starting monitoring checks..."

check_disk_space
check_response_time
check_database
check_memory

log_message "Monitoring checks completed"
MONITOR_SCRIPT_EOF

chmod +x bin/monitor

# Create environment file template
cat > .env.example << 'ENV_EXAMPLE_EOF'
# Database Configuration
DATABASE_NAME=ptc_windchill_event_production
DATABASE_USERNAME=ptc_app
DATABASE_PASSWORD=your_secure_password_here
DATABASE_HOST=localhost
DATABASE_PORT=5432

# Application Configuration
SECRET_KEY_BASE=your_secret_key_base_here
DOMAIN=ptcwindchill-events.com
RAILS_ENV=production

# Email Configuration
SMTP_SERVER=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password

# Redis Configuration (for Sidekiq)
REDIS_URL=redis://localhost:6379/1

# Monitoring
ALERT_EMAIL=admin@ptc.com

# SSL (Let's Encrypt)
CERTBOT_EMAIL=admin@ptc.com
