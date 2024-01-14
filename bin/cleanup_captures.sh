#!/bin/bash

# Configuration
MAX_USAGE=85          # Max disk usage percentage after which cleanup is triggered
CAPTURE_DIR="/captures"   # Directory where capture files are stored
HOURS_OLD=12          # Age in hours after which files are considered for deletion

# Function to output a log message with a timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check the status of tshark_capture.service
SERVICE_STATUS=$(systemctl is-active tshark.service)

# Bail out silently if tshark_capture.service is not active
if [ "$SERVICE_STATUS" != "active" ]; then
    exit 0
fi

# Check current disk usage
CURRENT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

# Compare current usage with the threshold
if [ "$CURRENT_USAGE" -ge "$MAX_USAGE" ]; then
    log_message "Disk usage is above $MAX_USAGE%. Cleaning up old files..."

    # Find and delete files older than HOURS_OLD
    find "$CAPTURE_DIR" -type f -mmin +$((HOURS_OLD*60)) -exec rm -f {} \;
else
    log_message "Disk usage is under control $CURRENT_USAGE%."
fi
