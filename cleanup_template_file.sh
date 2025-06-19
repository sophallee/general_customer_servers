#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status
error_log="error.log"  # Define an error log file
properties_filename='server.properties'
properties_template_filename='server.properties.template'

function log_error() {
    echo "error: $1" | /usr/bin/tee -a "$error_log"
    echo "Aborting program ..."
    echo " "
    exit 10
}

function update_config_file() {
    local flag=$1
    local expression=$2
    local file=$3

    echo -n "Updating $file with expression $expression ... "
    sed -i.bak -E "$expression" "$file"

    echo "OK"
}

function cp_file() {
    local src_file=$1
    local dest_file=$2
    local option=$3

    echo -n "Copying $src_file to $dest_file ... "

    if [ -z "$option" ]; then
        cp "$src_file" "$dest_file"
    else
        cp "$option" "$src_file" "$dest_file" 
    fi

    echo "OK"
}

cp_file "$properties_filename" "$properties_template_filename" -f
update_config_file -i "s/_passwd=.*/_passwd=''/g" "$properties_template_filename"
update_config_file -i "s/_password=.*/_password=''/g" "$properties_template_filename"
update_config_file -i "s/^timezone=.*/timezone='Australia'/g" "$properties_template_filename"
update_config_file -i "s/^domain=.*/domain=''/g" "$properties_template_filename"
update_config_file -i "s/^license=.*/license=''/g" "$properties_template_filename"
update_config_file -i "s/^server_ip=.*/server_ip=''/g" "$properties_template_filename"
update_config_file -i "s/^webapps_ip=.*/webapps_ip=''/g" "$properties_template_filename"
update_config_file -i "s/^pmds_ip=.*/pmds_ip=''/g" "$properties_template_filename"
update_config_file -i "s/^webapps_ip=.*/webapps_ip=''/g" "$properties_template_filename"
update_config_file -i "s/^oem_ip=.*/oem_ip=''/g" "$properties_template_filename"
update_config_file -i "s/^checksum_on=.*/checksum_on=false/g" "$properties_template_filename"
update_config_file -i "s/^(user[0-9]+_(name|group|passwd))=.*$/\1=''/g" "$properties_template_filename"
update_config_file -i "s|^nomachine_customer_name=.*|nomachine_customer_name=''|g" "$properties_template_filename"
update_config_file -i "s/^nomachine_port=.*/nomachine_port=''/g" "$properties_template_filename"
update_config_file -i "s/^ssh_permitted_network_internal=.*/ssh_permitted_network_internal=''/g" "$properties_template_filename"

#update_config_file -i "s/^=.*/=''/g" "$properties_template_filename"
