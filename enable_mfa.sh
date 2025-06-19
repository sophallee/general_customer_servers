#!/bin/bash
script_file=$(basename "$0")
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
script_name=$(echo $script_file | cut -d. -f 1)
cd $script_dir

if [ ! -f "common.sh" ]; then 
    echo "File common.sh not found."; exit 10; 
else
    source common.sh
fi

if [ ! -f "$script_dir/desktop.properties" ]; then log_error "File desktop.properties not found."; fi
if [ ! -f "$script_dir/desktop.master.properties" ]; then log_error "File desktop.master.properties not found."; fi

source desktop.master.properties
source desktop.properties

# uncomment the specific lines
update_config_file -i 's/^#\s*auth\s\+required\s\+pam_unix.so\s\+try_first_pass/auth    required      pam_unix.so    try_first_pass/' $pam_ssh_file
update_config_file -i 's/^#\s*auth\s\+\[success=1 default=ignore\]\s\+pam_access.so\s\+accessfile=\/etc\/security\/access-local.conf/auth [success=1 default=ignore] pam_access.so accessfile=\/etc\/security\/access-local.conf/' $pam_ssh_file
update_config_file -i 's/^#\s*auth\s\+required\s\+pam_google_authenticator.so/auth    required      pam_google_authenticator.so/' $pam_ssh_file
