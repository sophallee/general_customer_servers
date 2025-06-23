#!/bin/bash
script_file=$(basename "$0")
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
script_name=$(echo $script_file | cut -d. -f 1)
cd $script_dir

if [ ! -f "$script_dir/common.sh" ]; then 
    echo "file common.sh not found."; exit 10; 
fi
source $script_dir/common.sh

if [ ! -f $script_dir/state_file ]; then
    cp_file $script_dir/config_files/state_file.template  $script_dir/state_file 
fi

if [ ! -f "$script_dir/variables_check.sh" ]; then log_error "file variables_check.sh not found."; fi
if [ ! -f "$script_dir/software_install.sh" ]; then log_error "file software_install.sh not found."; fi
if [ ! -f "$script_dir/setup_users.sh" ]; then log_error "file setup_users.sh not found."; fi
if [ ! -f "$script_dir/state_file" ]; then log_error "file state_file not found."; fi
if [ ! -f "$script_dir/server.properties" ]; then log_error "file server.properties not found."; fi
if [ ! -f "$script_dir/server.master.properties" ]; then log_error "file server.master.properties not found."; fi

source $script_dir/server.master.properties
source $script_dir/server.properties

if ! whoami | grep -q 'root'; then
    log_error "script require elevated privileges. run sudo ./$script_file."
fi

if [ -z "$SUDO_USER" ] || [ "$SUDO_USER" == "root" ] ; then
    log_error "script cannot run in root shell. run sudo ./$script_file as a normal user."
fi

echo "checking variables ... "
shopt -s expand_aliases
source "$script_dir/variables_check.sh"
source "$script_dir/software_install.sh"
source "$script_dir/setup_users.sh"
source "$script_dir/state_file"

# username and password
check_if_empty "root_passwd" "$root_passwd"
check_if_empty "autoit_passwd" "$autoit_passwd"

IFS=',' read -ra cidr_array <<< "$ssh_permitted_network_internal"

for cidr in "${cidr_array[@]}"; do
    echo "Checking $cidr"
    check_private_ip_or_mask_cidr "$cidr"
    # Put your check logic here
done

for (( i=1; i <= $max_users; i++ )); do 
    user_name="user${i}_name" 
    if [ -z "${!user_name}" ]; then 
        break;
    fi
    user_passwd="user${i}_passwd" 
    check_if_empty "user${i}_passwd" "${!user_passwd}"
done

# source the /etc/os-release file
source /etc/os-release

# check for almalinux and version
if [ "$ID" == "almalinux" ]; then
  version_id=$( echo $VERSION_ID | cut -d. -f1)

  # check for version using version_id variable
  if [ $version_id -eq 8 ]; then
    echo "almalinux 8 detected."
  elif [ $version_id -eq 9 ]; then
    echo "almalinux 9 detected."
  else
    echo "this system is almalinux, but version detection failed."
  fi
else
  echo "this system is not almalinux."
fi

create_directory certificates
cp_file "/etc/skel/.bash*" /root 

stop_service "sssd"
remove_file "/var/lib/sss/db/*"
start_service "sssd"

# set the password policy for linux accounts
echo -n "setting password policies ... "
update_config_file '-i -e' '/# minlen =/s/# minlen/minlen/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# ucredit =/s/# ucredit/ucredit/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# lcredit =/s/# lcredit/lcredit/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# dcredit =/s/# dcredit/dcredit/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# ocredit =/s/# ocredit/ocredit/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# enforcing =/s/# enforcing/enforcing/' /etc/security/pwquality.conf
update_config_file '-i -e' '/# enforce_for_root/s/# enforce_for_root/enforce_for_root/' /etc/security/pwquality.conf
update_config_file '-i -e' 's/minlen = .*/minlen = 12/' /etc/security/pwquality.conf
update_config_file '-i -e' 's/ucredit = .*/ucredit = 1/' /etc/security/pwquality.conf
update_config_file '-i -e' 's/lcredit = .*/lcredit = 1/' /etc/security/pwquality.conf
update_config_file '-i -e' 's/dcredit = .*/dcredit = 1/' /etc/security/pwquality.conf
update_config_file '-i -e' 's/ocredit = .*/ocredit = 1/' /etc/security/pwquality.conf

echo " "
echo "creating the users ... "
update_password root "$root_passwd"
update_password autoit "$autoit_passwd"

if [ $create_support_user = true ]; then
    check_if_empty "support_passwd" "$support_passwd"
    groupadd sftp_only
    add_system_user pick "/etc/skel"
    add_to_group "pick" "sftp_only"
    update_password pick "$support_passwd"
fi

for (( i=1; i <= $max_users; i++ )); do 
    user_name="user${i}_name" 
    user_group="user${i}_group" 
    if [ -z "${!user_name}" ]; then 
        break;
    fi
    add_user "${!user_name}" "/etc/skel/shell"
    if [ ! -z "${!user_group}" ]; then
        add_to_group "${!user_name}" "${!user_group}"
    fi
    user_passwd="user${i}_passwd" 
    update_password "${!user_name}" "${!user_passwd}"
    passwd --expire "${!user_name}"
    ssh_allowed_localhost=$(echo "$ssh_allowed_localhost ${!user_name}")
    ssh_allowed_internal=$(echo "$ssh_allowed_internal ${!user_name}")
done

echo -n "copy over the cron files  ... "
cp_file config_files/alma8_oem_cron_autoit /var/spool/cron/autoit
cp_file config_files/alma8_oem_cron_aitscripts /var/spool/cron/aitscripts
change_ownership /var/spool/cron/autoit autoit autoit
change_ownership /var/spool/cron/aitscripts aitscripts aitscripts
change_permission "/var/spool/cron/*" 600

create_directory "/home/$SUDO_USER/bin"
create_directory "/home/$SUDO_USER/config"
change_ownership /home/$SUDO_USER/bin autoit autoit -R
change_ownership /home/$SUDO_USER/config autoit autoit -R
cp_file $script_dir/scripts/capture_system_info.sh /home/$SUDO_USER/bin
change_permission "/home/$SUDO_USER/bin/capture_system_info.sh" 700

create_directory "/home/aitscripts/bin"
cp_file $script_dir/scripts/backup_partition_table.sh /home/aitscripts/bin
change_permission /home/aitscripts/bin/backup_partition_table.sh 700

if [ $state_server_config = false ]; then

    update_config_file -i 's/^AllowZoneDrifting=.*/AllowZoneDrifting=no/' /etc/firewalld/firewalld.conf
    restart_service "firewalld"

    if [ ! -f '/usr/local/bin/whatismyip' ]; then 
        # create customer scripts
        # script to get ip information
        echo "adding whatismyip script ... "
        echo 'PATH=$PATH:/usr/local/bin:/usr/local/sbin' > /etc/profile.d/addpath.sh
        if [ $? -ne 0 ]; then log_error "adding updating paths in /etc/profile.d/addpath.sh"; fi
        echo '#!/bin/bash' > /usr/local/bin/whatismyip
        if [ $? -ne 0 ]; then log_error "adding updating whatismyip script"; fi
        echo 'dig +short myip.opendns.com @resolver1.opendns.com' >> /usr/local/bin/whatismyip
        if [ $? -ne 0 ]; then log_error "adding updating whatismyip script"; fi
        chmod 755 /usr/local/bin/whatismyip
        if [ $? -ne 0 ]; then log_error "error changing permission of whatismyip"; fi
    fi

    # increase the security limits
    if ! grep -q "soft    core    10000000" /etc/security/limits.conf; then
        echo "*   soft    core    10000000" >> /etc/security/limits.conf
    fi
    update_config_file "-i" "s/DefaultLimitCORE=.*/DefaultLimitCORE=infinity/" "/etc/systemd/system.conf"

    cp_file "$script_dir/config_files/sudoers-cmnd-general.template" $custom_sudoers_path/sudoers-cmnd-general
    cp_file "$script_dir/config_files/sudoers-defaults.template" $custom_sudoers_path/sudoers-defaults
    cp_file "$script_dir/config_files/sudoers-users-groups.template" $custom_sudoers_path/sudoers-users-groups

    echo -n "updateing secure paths in sudoers."
    update_config_file -i "s|secure_path =.*|secure_path = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/autoit/bin:/home/autoit/.local/bin|" /etc/sudoers
    if [ $? -ne 0 ]; then log_error "updateing secure paths in sudoers."; fi
    echo "ok"

    # ssh configuration
    if [ ! -f "/etc/ssh/sshd_config.original" ]; then 
        cp_file "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.original"; 
    fi
    create_directory "/etc/ssh/sshd_config.d" 

    if [ $version_id -eq 8 ]; then
        cp_file "config_files/sshd_config_alma8.template" /etc/ssh/sshd_config
        cp_file "config_files/sshd_config_alma8_custom.template" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    elif  [ $version_id -eq 9 ]; then
        cp_file "config_files/sshd_config_alma9.template" /etc/ssh/sshd_config
        cp_file "config_files/sshd_config_alma9_custom.template" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    fi  

    cp_file "config_files/access-local.conf.template" "/etc/security/access-local.conf"
    for mfa_exclude_network in $(echo "$ssh_permitted_network_internal" | sed "s/,/ /g"); do
        echo "+ : ALL : $mfa_exclude_network" >> /etc/security/access-local.conf    
    done
    echo "- : ALL : ALL" >> /etc/security/access-local.conf

    update_config_file -i "s/SSHD_CONFIG_PORT/$sshd_config_port/g" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    update_config_file -i "s/SSH_ALLOWED_LOCALHOST/$ssh_allowed_localhost/g" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    update_config_file -i "s/SSH_ALLOWED_INTERNAL/$ssh_allowed_internal/g" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    update_config_file -i "s|SSH_PERMITTED_NETWORK_INTERNAL|$ssh_permitted_network_internal|g" /etc/ssh/sshd_config.d/sshd_custom_rules.conf
    update_config_file -i "s|SSH_PERMITTED_NETWORK_EXTERNAL|$ssh_permitted_network_external|g" /etc/ssh/sshd_config.d/sshd_custom_rules.conf

    change_permission "/etc/ssh/sshd_config.d/sshd_custom_rules.conf" "600"
    firewall_add_port "$sshd_config_port" "tcp"
    firewall_reload     

    restart_service sshd

    if [ ! -f "/etc/pam.d/su.original" ]; then 
        cp_file "/etc/pam.d/su" "/etc/pam.d/su.original"; 
    fi
    cp_file "config_files/pam-su.template" "/etc/pam.d/su"

    if [ ! -f "/etc/pam.d/sshd.original" ]; then 
        cp_file "/etc/pam.d/sshd" "/etc/pam.d/sshd.original"; 
    fi
    cp_file "config_files/pam-sshd.template" "/etc/pam.d/sshd"

    echo -n "syncing time server ... "
    systemctl stop chronyd
    chronyd -q 'pool 2.almalinux.pool.ntp.org iburst'
    if [ $? -ne 0 ]; then log_error "syncing time server."; fi
    start_service chronyd    

    # change core dump location
    echo "changing core location to $crash_dump_path ... "
    create_directory "$crash_dump_path/kdump"
    create_directory "$crash_dump_path/apps"
    chmod 755 $crash_dump_path
    chmod 0700 $crash_dump_path/kdump
    chmod 0703 $crash_dump_path/apps
    update_config_file "-i -e" "s|^path .*|path $crash_dump_path/kdump|" /etc/kdump.conf

if ! grep -q "kernel.core_pattern = $crash_dump_path/apps" /etc/sysctl.conf; then
cat <<-'EOF' >> /etc/sysctl.conf
kernel.core_pattern = /home/crash/apps/core-%e--%u-%g-%p-%t
EOF
fi
    restart_service kdump

    echo -n "copying the rsyslog config ... "
    if [ -f config_files/rsyslog.conf.template ]; then
        if [ ! -f /etc/rsyslog.conf.original ]; then 
        cp_file /etc/rsyslog.conf /etc/rsyslog.conf.original -p
        fi
        cp_file config_files/rsyslog.conf.template /etc/rsyslog.conf
    else
        log_error "rsyslog template not found."
    fi
    echo "ok"

    chmod 644 /var/log/maillog*
    if [ $? -ne 0 ]; then log_error "changing permission on /var/log/maillog ."; fi

    echo -n "restarting rsyslogd server ... "
    systemctl restart rsyslog
    if [ $? -ne 0 ]; then log_error "restarting rsyslogd server."; fi
    echo "ok"

    echo "add user and server config complete."
    update_config_file -i 's/state_server_config=.*/state_server_config=true/' $script_dir/$state_file  
fi

change_ownership /home/autoit autoit autoit -R