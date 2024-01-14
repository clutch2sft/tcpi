#!/bin/bash

# Function to send logs to syslog
log_message() {
    level=$1
    message=$2
    logger -p "user.$level" -t "wlan0-set-ip" "$message"
}

# Function to check if wlan0 is connected to agclogen
check_wlan0_agclogen() {
    while true; do
        # Check the current connection of wlan0
        connection=$(nmcli -t -f GENERAL.CONNECTION device show wlan0 | cut -d: -f2 | xargs) # xargs trims whitespace

        if [ "$connection" == "agclogen" ]; then
            log_message "INFO" "wlan0 is connected to agclogen."
            break
        elif [ -n "$connection" ]; then
            log_message "ERROR" "wlan0 is connected to a different network: $connection. Exiting script."
            exit 1
        else
            log_message "DEBUG" "Waiting for wlan0 to connect to agclogen..."
            sleep 5
        fi
    done
}

# Ensure wlan0 is connected to agclogen
check_wlan0_agclogen

available_ip=""
for ip in $(seq 254 -1 247); do
    if arping -0 -c 2 -w 3 -I wlan0 120.13.212.$ip | grep -q "Timeout"; then
        log_message "INFO" "Available IP: 120.13.212.$ip"
        available_ip="120.13.212.$ip"
        available_gw="120.13.212.1"
        break
    else
        log_message "DEBUG" "IP 120.13.212.$ip is in use. Checking next."
    fi
done

# Check if an available IP was found
if [ -z "$available_ip" ]; then
    log_message "WARN" "No available 120.13.212.x addresses in the specified range. Exiting."
    exit 1
else
    log_message "INFO" "Assigning new IP:$available_ip and gateway:$available_gw to agclogen"
    nmcli con down agclogen
    nmcli con mod agclogen ipv4.method auto
    nmcli con mod agclogen ipv4.gateway ""
    nmcli con mod agclogen ipv4.addresses ""
    nmcli con mod agclogen ipv4.method manual ipv4.addresses $available_ip/24 ipv4.gateway $available_gw
    nmcli con up agclogen
fi

exit 0
