#!/bin/bash

# List of IP lookup services to try (in order)
ip_services=(
    "dig +short myip.opendns.com @resolver1.opendns.com"
    "curl -s ifconfig.me"
    "curl -s ipinfo.io/ip"
    "curl -s api.ipify.org"
    "curl -s ident.me"
    "curl -s ipecho.net/plain"
)

# Function to validate IP address
is_valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 &&
           ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Try each service until we get a valid IP
for service in "${ip_services[@]}"; do
    ip=$($service 2>/dev/null)
    
    # Remove any surrounding whitespace or control characters
    ip=$(echo "$ip" | xargs)
    
    if is_valid_ip "$ip"; then
        echo "$ip"
        exit 0
    fi
done

echo "error: could not determine public IP address from any service" >&2
exit 1