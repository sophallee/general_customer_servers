#!/bin/bash
source webapps.properties

CONN_NAME=$(nmcli c | grep ethernet | awk '{ print $1 }')

log_error() {
	echo "Error: $1" | /usr/bin/tee $ERROR_LOG
	echo "Aborting program ... "
	echo " "
	exit 10
}

sed -i -e "s/$VMHOST_IP/$ONSITE_VMHOST_IP/" /etc/hosts
sed -i -e "s/$PMDS_IP/$ONSITE_PMDS_IP/" /etc/hosts
sed -i -e "s/$WEBAPPS_IP/$ONSITE_WEBAPPS_IP/" /etc/hosts
sed -i -e "s/$OEM_IP/$ONSITE_OEM_IP/" /etc/hosts

# Setup the network
nmcli connection modify $CONN_NAME ipv4.addresses $ONSITE_WEBAPPS_IP_CIDR
nmcli connection modify $CONN_NAME ipv4.gateway $ONSITE_GW
nmcli connection modify $CONN_NAME ipv4.dns "$ONSITE_DNS"
nmcli connection modify $CONN_NAME ipv4.dns-search $DNS_SEARCH
nmcli connection modify $CONN_NAME ipv4.method manual
nmcli connection modify $CONN_NAME connection.autoconnect yes
nmcli connection down $CONN_NAME && nmcli connection up $CONN_NAME
