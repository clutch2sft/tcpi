#!/bin/bash

# Function to send logs to syslog
log_message() {
    level=$1
    message=$2
    logger -p "user.$level" -t "boot-ip-reset" "$message"
}

# Check if the connection is already up
if nmcli con show --active | grep -q "agclogen"; then
    log_message "INFO" "Connection 'agclogen' is already up. No action taken."
else
    # Set the connection to DHCP (auto) first to clear any existing static configuration
    nmcli con mod agclogen ipv4.method auto
    nmcli con mod agclogen ipv4.gateway ""
    nmcli con mod agclogen ipv4.addresses ""

    # Set a known safe IP address
    nmcli con mod agclogen ipv4.method manual ipv4.addresses 192.168.99.50/24 ipv4.gateway 192.168.99.1

    log_message "INFO" "Connection 'agclogen' set to safe IP 192.168.99.50/24."
fi

exit 0
