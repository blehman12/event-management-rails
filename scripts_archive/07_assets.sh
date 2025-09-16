#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 7: Setting up assets"

cd "$APP_NAME"

mkdir -p app/assets/stylesheets
cat > app/assets/stylesheets/application.css << 'EOF'
/*
 *= require_tree .
 *= require_self
 */

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
EOF

mkdir -p app/javascript
cat > app/javascript/application.js << 'EOF'
import "@hotwired/turbo-rails"
import "controllers"
EOF

mkdir -p app/javascript/controllers
cat > app/javascript/controllers/application.js << 'EOF'
import { Application } from "@hotwired/stimulus"
const application = Application.start()
application.debug = false
window.Stimulus = application
export { application }
EOF

cat > app/javascript/controllers/index.js << 'EOF'
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
EOF

cat > config/importmap.rb << 'EOF'
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
EOF

echo "✓ Assets setup completed"
