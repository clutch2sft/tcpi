#!/bin/bash


mkdir -p /captures

read_ips_from_ini() {
    local ini_file="/opt/rtshark-app/.config/tshark_filter.ini"
    local ips=()
    echo "Extracting IP addresses" >&2
    if [[ -f "$ini_file" ]]; then
        while IFS= read -r line; do
            # Convert line to lowercase
            local lower_line=$(echo "${line,,}" | sed 's/ *= */=/')
            echo "lower_line: $lower_line" >&2
            if [[ $lower_line == ipaddresses=* ]]; then
                echo "setting ip string" >&2
                ips_string="${lower_line#ipaddresses=}"
                IFS=',' read -ra ips <<< "$ips_string"
                break
            fi
        done < "$ini_file"
    else
        echo "Did not find ini file" >&2
    fi

    local ip_filter_parts=()
    for ip in "${ips[@]}"; do
        ip_filter_parts+=("(host $ip)")
    done


    # Join the filter parts with 'or'
    if [ ${#ip_filter_parts[@]} -ne 0 ]; then
        ip_filter="${ip_filter_parts[0]}"
        for ip_part in "${ip_filter_parts[@]:1}"; do
            ip_filter+=" or $ip_part"
        done
        echo "not port 22 and ($ip_filter)"
    else
        echo "not port 22"
    fi
}




# Function to execute when the script is stopped
cleanup() {
    echo "TShark capture stopped at $(date)" >&2
    # any other cleanup commands
    chgrp -R pi /captures/* #just add this line
    chmod 644 /captures/* #and this line
}
trap cleanup SIGTERM
# Get the IP address of br0
IP_ADDR=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Get the dynamically constructed IP address filter
IP_FILTER=$(read_ips_from_ini)

# Define the tshark capture filter to include the IP filter
CAPTURE_FILTER="($IP_FILTER)"

# Define the tshark capture filter to exclude SSH to its own IP
#CAPTURE_FILTER="not (dst port 22 and dst host $IP_ADDR)"
#CAPTURE_FILTER="not port 22"




# Get the current date and time for the filename
CURRENT_TIME=$(date +"%Y%m%d-%H%M%S")

# Define the path for the capture file with the timestamp
#CAPTURE_PATH="/mnt/ramdisk/capture_$CURRENT_TIME.pcap"
#CAPTURE_PATH="/captures/capture.pcap"

# Get the current hostname
HOSTNAME=$(hostname)

# Define the path for the capture file with the hostname
CAPTURE_PATH="/captures/capture_${HOSTNAME}.pcap"

FILE_SIZE_LIMIT=76800  # In kilobytes, for 75MB
MAX_FILES=200            # Maximum number of files to keep
#BUFFER_SIZE=150     # Buffer size in MB
#BUFFER_SIZE=1

# Get free memory in kilobytes (KB)
FREE_MEM_KB=$(awk '/MemFree/ {print $2}' /proc/meminfo)

# Convert free memory to megabytes (MB), divide by 2, and round up
BUFFER_SIZE=$(( (FREE_MEM_KB + 2047) / 2048 ))


echo $CAPTURE_FILTER

#echo $CURRENT_TIME

#echo $CAPTURE_PATH

#echo $FILE_SIZE_LIMIT

#echo $MAX_FILES

#echo $BUFFER_SIZE

#_COMMAND='/usr/bin/tshark -i eth0 -f "$CAPTURE_FILTER" -b filesize:$FILE_SIZE_LIMIT -b files:$MAX_FILES -w $CAPTURE_PATH -B $BUFFER_SIZE'

#echo $_COMMAND

# Run tshark with the necessary options
/usr/bin/tshark -i eth0 -f "$CAPTURE_FILTER" -b filesize:$FILE_SIZE_LIMIT -b files:$MAX_FILES -w $CAPTURE_PATH -B $BUFFER_SIZE
#/usr/bin/tshark -i eth0 -f "$CAPTURE_FILTER" -b filesize:$FILE_SIZE_LIMIT -b files:$MAX_FILES -w $CAPTURE_PATH 
