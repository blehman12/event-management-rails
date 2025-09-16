#!/bin/bash

# PTC Windchill Event App - Master Build Script (Updated)
# Runs all individual scripts in proper sequence to build complete application
# Usage: ./master_build_script.sh [app_name] [start_from_script]

set -e

# Configuration
APP_NAME="${1:-ptc_windchill_event}"
START_FROM="${2:-1}"
SCRIPT_DIR="$(pwd)"
LOG_FILE="build_log_$(date +%Y%m%d_%H%M%S).txt"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "PTC WINDCHILL EVENT APP - MASTER BUILD"
echo "========================================="
echo "App Name: $APP_NAME"
echo "Starting from script: $START_FROM"
echo "Log file: $LOG_FILE"
echo "Build started at: $(date)"
echo ""

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to run script with error handling
run_script() {
    local script_num=$1
    local script_name=$2
    local script_file=$3
    
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}RUNNING SCRIPT $script_num: $script_name${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    if [ ! -f "$script_file" ]; then
        echo -e "${RED}ERROR: Script $script_file not found!${NC}"
        return 1
    fi
    
    # Make script executable
    chmod +x "$script_file"
    
    # Run script and capture output
    if ./"$script_file" "$APP_NAME" 2>&1 | tee -a "$LOG_FILE"; then
        echo -e "${GREEN}✓ Script $script_num completed successfully${NC}"
        echo "Completed: $script_name at $(date)" >> "$LOG_FILE"
        return 0
    else
        echo -e "${RED}✗ Script $script_num failed!${NC}"
        echo "FAILED: $script_name at $(date)" >> "$LOG_FILE"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if Ruby is installed
    if ! command -v ruby >/dev/null 2>&1; then
        echo -e "${RED}Ruby not found. Please install Ruby first.${NC}"
        exit 1
    fi
    
    # Check if Rails is installed or can be installed
    if ! command -v rails >/dev/null 2>&1; then
        echo -e "${YELLOW}Rails not found. Will be installed in initial setup.${NC}"
    fi
    
    # Check if we're in the right directory (scripts should be present)
    local required_scripts=("01_initial_setup.sh" "02_devise_setup.sh" "14_env_checks_and_updates.sh")
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            echo -e "${RED}Required script $script not found in current directory.${NC}"
            echo "Please ensure all script files are in the current directory."
            exit 1
        fi
    done
    
    echo -e "${GREEN}Prerequisites check passed.${NC}"
}

# Main execution
main() {
    # Check prerequisites first
    check_prerequisites
    
    # Array of scripts in execution order with updated script list
    declare -a SCRIPTS=(
        "1:Initial Setup:01_initial_setup.sh"
        "2:Devise Setup:02_devise_setup.sh"
        "3:Models Creation:03_models.sh"
        "4:Controllers:04_controllers.sh"
        "5.1:Non-Admin User Fix:05.1_tmp_fix_non_admin_user.sh"
        "5:Admin Controllers:05_admin_controllers.sh"
        "6:Views:06_views.sh"
        "7:Assets:07_assets.sh"
        "8:Database Seeds:08_seeds.sh"
        "9:Vendor Management:09_vendor_management_script.sh"
        "10:Admin Views:10_admin_views_script.sh"
        "11:Enhanced Seeds:11_enhanced_seeds.sh"
        "12.1:Admin Layout Fix:12.1_fix_admin_layouts.sh"
        "12:Admin Controllers Fix:12_fix_admin_controllers.sh"
        "13:Admin Safety:13_admin_safety_features.sh"
        "14.1:Environment Fix:14.1_fix.sh"
        "14:Environment Setup:14_env_checks_and_updates.sh"
        "15.1:Analytics Reporting:15_analytics_reporting.sh"
        "15:Bulk User Support:15_bulk_user_support.sh"
        "16.1:After Run Fix:16_after_run_fix.sh"
        "16.2:User Issue Fix:16_after_run_fix_user_issue.sh"
        "16:Production Setup:16_production_setup.sh"
        "18:Email Notifications:18_email_notifications.sh"
        "19:Calendar Export:19_calendar_export.sh"
        "20:Bulk User Management:20_bulk_user_management.sh"
    )
    
    # Track success/failure
    local success_count=0
    local total_scripts=${#SCRIPTS[@]}
    local failed_scripts=()
    
    echo "Total scripts to run: $total_scripts"
    echo "Starting from script: $START_FROM"
    echo ""
    
    # Run each script
    for script_info in "${SCRIPTS[@]}"; do
        IFS=':' read -r num name file <<< "$script_info"
        
        # Skip if before start point (handle decimal numbers)
        if (( $(echo "$num < $START_FROM" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${YELLOW}Skipping script $num (before start point)${NC}"
            continue
        fi
        
        # Check if file exists before running
        if [ ! -f "$file" ]; then
            echo -e "${YELLOW}Skipping script $num: $file (file not found)${NC}"
            continue
        fi
        
        # Run the script
        if run_script "$num" "$name" "$file"; then
            ((success_count++))
            
            # Optional: Brief pause between scripts
            sleep 2
        else
            failed_scripts+=("$num:$name")
            echo -e "${RED}Build failed at script $num: $name${NC}"
            echo ""
            echo "Check the log file for details: $LOG_FILE"
            break
        fi
        
        echo ""
    done
    
    # Final report
    echo "========================================="
    echo "BUILD COMPLETION REPORT"
    echo "========================================="
    echo "Total scripts available: $total_scripts"
    echo "Successfully completed: $success_count"
    echo "Build finished at: $(date)"
    
    if [ ${#failed_scripts[@]} -eq 0 ] && [ $success_count -gt 0 ]; then
        echo -e "${GREEN}✓ BUILD SUCCESSFUL!${NC}"
        echo ""
        echo "Application is ready at: ./$APP_NAME"
        echo "To start the server:"
        echo "  cd $APP_NAME"
        echo "  rails server"
        echo ""
        echo "Admin access: http://localhost:3000/admin"
        echo "Login: admin@ptc.com / password123"
        
        # Quick verification
        if [ -d "$APP_NAME" ] && [ -f "$APP_NAME/config/routes.rb" ]; then
            echo ""
            echo "Quick verification:"
            cd "$APP_NAME"
            echo "✓ Application directory exists"
            echo "✓ Routes configured"
            if [ -f "db/schema.rb" ]; then
                echo "✓ Database schema present"
            fi
            if [ -d "app/views/admin" ]; then
                echo "✓ Admin views created"
            fi
            if [ -f "app/controllers/admin/bulk_users_controller.rb" ]; then
                echo "✓ Bulk user management available"
            fi
            if [ -f "bin/deploy" ]; then
                echo "✓ Production deployment scripts ready"
            fi
            cd ..
        fi
        
    else
        echo -e "${RED}✗ BUILD FAILED${NC}"
        echo "Failed scripts:"
        for failed in "${failed_scripts[@]}"; do
            echo "  - $failed"
        done
    fi
    
    echo ""
    echo "Detailed log available in: $LOG_FILE"
}

# Cleanup function
cleanup() {
    echo ""
    echo "Build interrupted. Cleaning up..."
    if [ -d "$APP_NAME" ] && [ "$START_FROM" -eq 1 ]; then
        echo "Removing partially built application..."
        rm -rf "$APP_NAME"
    fi
}

# Set trap for cleanup on interrupt
#trap cleanup EXIT

# Check if bc is available for decimal comparison
if ! command -v bc >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: bc not found. Install bc for better decimal script number handling.${NC}"
fi

# Run main function
main

# If we get here, disable the cleanup trap
#trap - EXIT