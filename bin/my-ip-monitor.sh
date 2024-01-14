#!/bin/bash

# Function to send logs to syslog
# Define log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Set the minimum log level for messages to be recorded
MIN_LOG_LEVEL=$LOG_LEVEL_INFO

# Function to send logs to syslog
log_message() {
    level_name=$1
    message=$2

    # Assign numeric values to level names
    case $level_name in
        DEBUG)
            level=$LOG_LEVEL_DEBUG
            level_priority="user.debug"
            ;;
        INFO)
            level=$LOG_LEVEL_INFO
            level_priority="user.info"
            ;;
        WARN)
            level=$LOG_LEVEL_WARN
            level_priority="user.warn"
            ;;
        ERROR)
            level=$LOG_LEVEL_ERROR
            level_priority="user.err"
            ;;
        *)
            echo "Unknown log level: $level_name"
            exit 1
            ;;
    esac

    # Check if the message's level is greater than or equal to the minimum level
    if [ $level -ge $MIN_LOG_LEVEL ]; then
        logger -p $level_priority -t "my-ip-monitor" "$message"
    fi
}


while true; do
    current_ip=$(nmcli -t -f IP4.ADDRESS dev show wlan0 | awk -F: '{print $2}' | cut -d'/' -f1)
    if [ -z "$current_ip" ]; then
        log_message "WARN" "No IP address found on wlan0. Skipping arping check."
    else
        # Check for timeout response
        if ! arping -0 -c 2 -w 3 -I wlan0 $current_ip | grep -q "Timeout"; then
            log_message "ERROR" "IP conflict detected for $current_ip. Reverting to fallback IP."
            nmcli con down agclogen
            nmcli con mod agclogen ipv4.method auto
            nmcli con mod agclogen ipv4.gateway ""
            nmcli con mod agclogen ipv4.addresses ""
            nmcli con mod agclogen ipv4.method manual ipv4.addresses 192.168.99.50/24 ipv4.gateway 192.168.99.1
            nmcli con up agclogen
            systemctl restart find_wlan_ip_and_set.service
        else
            log_message "DEBUG" "No IP conflict detected for $current_ip."
        fi
    fi
    sleep 60
done
