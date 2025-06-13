#!/bin/bash

# Type checking
check_if_empty () {
    local variable_name=$1
    local variable_value=$2
    if [ -z $variable_value ]; then log_error "Variable cannot be empty: $variable_name."; fi
}

check_isboolean () {
    local regexp='="true"$\|="false"$'
    local variable=$1
    if ! declare -p $variable | grep -q $regexp; then log_error "Variable $variable is not a boolean."; fi
}

check_isnumber () {
    local regexp='^[0-9]+$'
    local variable=$1
    if ! echo $variable | grep -P $regexp >/dev/null; then log_error "Variable $variable is not a number."; fi
}

check_within_range () {
    local min=$1
    local max=$2
    local value=$3
    local item=$4
    if [ -z "$value" ] || [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then log_error "$item out of range. $item must be between $min and $max.";fi
}

check_username () {
    local regexp='^[a-z][-a-z0-9_]+$'
    local username=$1
    if ! echo $username | grep -P $regexp >/dev/null; then log_error "Username must start with lowercase letters and can only contain lowercase letters, numbers, hypens and underscore."; fi
}

check_password () {
    local password=$1
    password_len=${#password}
    if [ $password_len -lt 10 ]; then log_error "Password need to be more than 10 characters long."; fi
    upper_len=$(echo $password | grep -o [A-Z] | tr -d "\n" | wc -m)
    if [ $upper_len -lt 2 ]; then log_error "Password need to be have at least 2 upper case characters."; fi
    lower_len=$(echo $password | grep -o [a-z] | tr -d "\n" | wc -m)
    if [ $lower_len -lt 2 ]; then log_error "Password need to be have at least 2 lower case characters."; fi
    digit_len=$(echo $password | grep -o [0-9] | tr -d "\n" | wc -m)
    if [ $digit_len -lt 2 ]; then log_error "Password need to be have at least 2 digits."; fi   
    special_len=$(echo $password | sed 's/[^][`~!@#$%^&*()-_=+{}|\;:"'\'',./<>?]//g' | awk '{ print length }')
    if [ $special_len -lt 2 ]; then log_error "Password need to be have at least 2 special characters."; fi
}

check_disk_exist () {
	local disk=$1
    if [ ! -b "$disk" ] ||  [ -z "$disk" ]; then log_error "Disk does not exist."; fi
}

check_disk_unpartitioned () {
    local disk=$1
    if ! parted $disk print 2>/dev/null | grep -q 'unknown'; then log_error "$disk is not a valid disk. Please specify an unpartitioned disk."; fi
}

check_disk_name () {
    local regexp='^[a-z][-a-z0-9_]+$'
    local username=$1
    if ! echo $username | grep -P $regexp >/dev/null; then log_error "Disk name must start with lowercase letters and can only contain lowercase letters, numbers, hypens and underscore."; fi
}

check_disk_size () {
    local regexp='^[0-9]+G$'
    local disk_size=$1
    if ! echo $disk_size | grep -q "100%FREE$" && ! echo $disk_size | grep -P $regexp >/dev/null; then log_error "Invalid disk size: $disk_size. Disk size is in gigabytes (Eg 10G)"; fi
}

check_sufficient_diskspace () {
    local disk=$1
    local pattern=$(echo $disk | awk -F "/" '{print $NF}')
    local total_disk_size count

    for var in "$@"; do
        if [ "$var" != "$disk" ]; then total_disk_size=$(( $total_disk_size + $(echo $var | tr -dc '0-9') )); fi
    done
    if [ "$total_disk_size" -ge "$(lsblk | grep 'disk' | grep $pattern | awk '{print $4}' | tr -dc '0-9')"  ]; then log_error "Allocated disk space exceeds the available disk space"; fi
}

check_timezone () {
    local timezone=$1
    if ! timedatectl list-timezones | grep -q "$timezone" || [ -z "$timezone" ]; then log_error "Not a valid timezone. Run timedatectl list-timezones to see all available time zones."; fi
}

check_hostname () {
    local regexp='^[a-z][-a-z0-9]+$'
    local hostname=$1
    if ! echo $hostname | grep -P $regexp >/dev/null; then log_error "Hostname must start with lowers letters and can only contain lowercase letters, numbers and hypens."; fi
}

check_domain() {
    REGEX='^([a-z0-9][a-z0-9-]{0,61}[a-z0-9]\.)+[a-z]{2,}$'
    VALID=$( echo $1 | grep -P "${REGEX}" )

    if [ -z "$VALID" ]; then
        log_error "Invalid domain name."
    fi
}

check_license () {
    local regexp='^[a-z][0-9]{1,2}$'
    local hostname=$1
    if ! echo $hostname | grep -P $regexp >/dev/null; then log_error "License is invalid. License starts with a alphabetical letter followed by a number."; fi
}

check_valid_ip() {
    local regexp='^[0-9]+$'
    local ip_address=$1
    IFS="./" read -r ip1 ip2 ip3 ip4 <<< "$ip_address"

    for var in "$ip1" "$ip2" "$ip3" "$ip4"; do
        VALID=$( echo $var | grep -P "$regexp" ) 
        
        if [ -z "$VALID" ]; then
            log_error "Invalid IP address."
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range."
        fi     
    done    

    if [ "$ip1" -gt 0 ] && [ "$ip1" -lt 224 ] && [ "$ip4" -ne 0 ] && [ "$ip4" -ne 255 ]; then
        return 0
    else
        log_error "Invalid IP address: $ip_address.\n"
    fi
}

check_private_ip() {
    local regexp='^[0-9]+$'
    local ip_address=$1
    IFS="./" read -r ip1 ip2 ip3 ip4 <<< "$ip_address"

    for var in "$ip1" "$ip2" "$ip3" "$ip4"; do
        VALID=$( echo $var | grep -P "$regexp" ) 
        
        if [ -z "$VALID" ]; then
            log_error "Invalid IP address."
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range."
        fi     
    done    

    if [ "$ip1" -eq 10 ]; then
        return 0
    elif [ "$ip1" -eq 172 ] && [ "$ip2" -ge 16 ] && [ "$ip2" -le 31 ]; then
        return 0
    elif [ "$ip1" -eq 192 ] && [ "$ip2" -eq 168 ]; then
        return 0
    else
        log_error "Invalid IP address.\n$ip_address is not a private IP address."
    fi
}

check_public_ip() {
    local regexp='^[0-9]+$'
    local ip_address=$1
    IFS="./" read -r ip1 ip2 ip3 ip4 <<< "$ip_address"

    for var in "$ip1" "$ip2" "$ip3" "$ip4"; do
        VALID=$( echo $var | grep -P "$regexp" ) 
        
        if [ -z "$VALID" ]; then
            log_error "Invalid IP address."
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range."
        fi     
    done    

    if [ "$ip1" -eq 10 ]; then
        log_error "Invalid IP address.\n$ip_address is not a public IP."
    elif [ "$ip1" -eq 172 ] && [ "$ip2" -ge 16 ] && [ "$ip2" -le 31 ]; then
        log_error "Invalid IP address.\n$ip_address is not a public IP."
    elif [ "$ip1" -eq 192 ] && [ "$ip2" -eq 168 ]; then
        log_error "Invalid IP address.\n$ip_address is not a public IP."
    else
        return 0
    fi
}


check_cidr() {
    # Parse "a.b.c.d/n" into five separate variables
    REGEX_NUMBER='^[0-9]+$'
    IFS="./" read -r ip1 ip2 ip3 ip4 N <<< "$1"

    for var in "$ip1" "$ip2" "$ip3" "$ip4"; do
        VALID=$( echo $var | grep -P "$REGEX_NUMBER" ) 
        
        if [ -z "$VALID" ]; then
            log_error "Invalid IP address.\nIP address should be in CIDR notation. E.g. 192.168.0.1/24"
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range. "
        fi
    done

    VALID=$( echo $N | grep -P "$REGEX_NUMBER" ) 
        
    if [ -z "$VALID" ]; then
        log_error "Invalid IP address.\nIP address should be in CIDR notation. E.g. 192.168.0.1/24"
    fi
    if [ "$N" -lt 0 ] || [ "$N" -gt 32 ]; then
        log_error "Invalid IP address.\n$var is not within a valid range. "
    fi
}

check_private_ip_cidr() {
    REGEX_NUMBER='^[0-9]+$'
    IFS="./" read -r ip1 ip2 ip3 ip4 N <<< "$1"

    for var in "$ip1" "$ip2" "$ip3" "$ip4" "$N"; do
        VALID=$( echo $var | grep -P "$REGEX_NUMBER" ) 

        if [ -z "$VALID" ]; then
            log_error "Invalid IP address.\nIP address should be in CIDR notation. E.g. 192.168.0.1/24"
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range."
        fi     
    done    

    if [ "$ip1" -eq 10 ]; then
        if [ "$N" -lt 8 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 8 to 32."
        fi
    elif [ "$ip1" -eq 172 ] && [ "$ip2" -ge 16 ] && [ "$ip2" -le 31 ]; then
        if [ "$N" -lt 12 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 12 to 32."
        fi
    elif [ "$ip1" -eq 192 ] && [ "$ip2" -ge 168 ]; then
        if [ "$N" -lt 16 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 16 to 32."
        fi
    else
        log_error "Invalid IP address.\n$1 is not a private IP address. "
    fi
}

check_private_ip_or_mask_cidr() {
    REGEX_NUMBER='^[0-9]+$'
    IFS="./" read -r ip1 ip2 ip3 ip4 N <<< "$1"

    for var in "$ip1" "$ip2" "$ip3" "$ip4" "$N"; do
        VALID=$( echo $var | grep -P "$REGEX_NUMBER" ) 

        if [ -z "$VALID" ]; then
            log_error "Invalid IP address.\nIP address should be in CIDR notation. E.g. 192.168.0.1/24"
        fi
        if [ "$var" -lt 0 ] || [ "$var" -gt 255 ]; then
            log_error "Invalid IP address.\n$var is not within a valid range."
        fi     
    done    
    
    if [ -z $N ]; then
        echo "No mask set."
    elif [ "$ip1" -eq 10 ]; then
        if [ "$N" -lt 8 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 8 to 32."
        fi
    elif [ "$ip1" -eq 172 ] && [ "$ip2" -ge 16 ] && [ "$ip2" -le 31 ]; then
        if [ "$N" -lt 12 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 12 to 32."
        fi
    elif [ "$ip1" -eq 192 ] && [ "$ip2" -ge 168 ]; then
        if [ "$N" -lt 16 ] || [ "$N" -gt 32 ]; then
            log_error "Invalid mask: $N. Mask should be from 16 to 32."
        fi
    else
        log_error "Invalid IP address.\n$1 is not a private IP address. "
    fi
}
