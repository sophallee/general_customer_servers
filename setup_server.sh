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

## checks go back here
echo "   checking sftp server variables."
check_domain $sftp_host_internal
check_domain $sftp_host_external
echo "   checking system variables."
check_domain $domain
check_timezone $timezone
if [ $license_check = true ]; then check_license $license; fi
echo "   checking host variables."
check_hostname $vmhost_name
check_hostname $pmds_name
check_hostname $webapps_name
if [ $hostname_ip_check = true ]; then 
echo "   checking IP variables."
    check_private_ip "$webapps_ip"
    check_private_ip "$pmds_ip"
    check_private_ip "$vmhost_ip"
fi

if [ $oem_check = true ]; then
    echo "   checking oem vm variables."
    check_hostname $oem_name
    if [ $hostname_ip_check = true ]; then 
        check_private_ip $oem_ip 
    fi
fi

if [ ! -f "$script_dir/config_files/$package_list" ]; then log_error "file package_list.txt not found."; fi

add_hostname_to_etc_hosts "$oem_ip" "$oem_name" "$oem_name.$domain"
add_hostname_to_etc_hosts "$webapps_ip" "$webapps_name" "$webapps_name.$domain"
add_hostname_to_etc_hosts "$pmds_ip" "$pmds_name" "$pmds_name.$domain"
add_hostname_to_etc_hosts "$vmhost_ip" "$vmhost_name" "$vmhost_name.$domain"

sftp_host_iso=''
sftp_host_packages=''

echo "testing sftp connection ... "
echo -n "    checking internal sftp server ($sftp_host_internal)."
echo "ls" | sudo -u "$SUDO_USER" sftp -o "StrictHostKeyChecking no"  "$sftp_host_internal_packages"  

if [ $? -ne 0 ]; then 
    echo "sftp connection failed to $sftp_host_internal."; 
else 
    sftp_host="$sftp_host_internal"
    sftp_host_packages="$sftp_host_internal_packages"
    echo "ok"
fi

if [ -z "$sftp_host_packages" ]; then 
    echo -n "    checking external sftp server ($sftp_host_external)."
    echo "ls" | sudo -u "$SUDO_USER" sftp -o "StrictHostKeyChecking no"  "$sftp_host_external_packages"
    if [ $? -ne 0 ]; then 
        log_error "sftp connection failed to $sftp_host_external."; 
    else 
        sftp_host="$sftp_host_external"
        sftp_host_packages="$sftp_host_external_packages"
        echo "ok"
    fi
fi

create_directory software
create_directory logs
create_directory temp
create_directory certificates

create_directory software
change_ownership . "$SUDO_USER" "$SUDO_USER" -R

if [ $state_sys_settings = false ]; then
    echo -n 'setting the timzezone ... '
    timedatectl set-timezone $timezone
    if [ $? -ne 0 ]; then log_error "setting the timzezone."; fi
    echo "ok"

    # setting the hostname
    echo -n "setting the hostname ... "
    hostnamectl set-hostname $server_name.$domain
    if [ $? -ne 0 ]; then log_error "set-hostname $server_name.$domain"; fi
    echo "ok"    

    if ! grep -q "set background" /etc/vimrc; then
        update_config_file -i "/set ruler/a set background=dark" /etc/vimrc
    else 
        update_config_file -i "s/set background=.*/set background=dark/" /etc/vimrc
    fi

    # create persistence logs
    echo -n "setting persitent logging ... "
    create_directory "/var/log/journal"

    update_config_file -i "s/^state_sys_settings=.*/state_sys_settings=true/" $script_dir/$state_file  
fi 

if [ $state_software_download = false ]; then
    remove_file "$script_dir/software/$software_checksum"
    echo -n "downloading software checksum ... "
    sudo -u "$SUDO_USER" sftp "$sftp_host_packages:/checksum/file_checksum.txt" "$script_dir/software/$software_checksum"  
    if [ $? -ne 0 ]; then log_error  "download failed from $sftp_host."; else echo ok; fi

    # downloading acronis installer 
    if [ ! -f "$script_dir/software/$acronis_bin" ]; then   
        echo -n "downloading acronis installer ... "     
        sudo -u "$SUDO_USER" sftp "$sftp_host_packages:/packages/$acronis_bin" "$script_dir/software"
        if [ $? -ne 0 ]; then log_error "download failed ($acronis_bin) from $sftp_host_packages."; else echo ok; fi   
    fi
    
    # checking packages
    if [ "$checksum_on" = true ]; then 
        # checking acronis installer 
        echo -n "checking acronis installer ... "
        acronis_bin_checksum=$(grep $acronis_bin "$script_dir/software/$software_checksum" | awk '{print $1}')
        file_sha256sum "$script_dir/software/$acronis_bin" $acronis_bin_checksum
        echo "ok"

    fi    

    find $script_dir -type d -print0 | xargs -0 chmod 0755
    find $script_dir -type f -print0 | xargs -0 chmod 0644
    find $script_dir -type f -name '*.sh' -print0 | xargs -0 chmod 0700
    find $script_dir -type f -name '*.bin' -print0 | xargs -0 chmod 0700

    update_config_file -i "s/^state_software_download=.*/state_software_download=true/" $script_dir/$state_file  
fi

if [ $state_software_install = false ]; then
    touch "$script_dir/logs/installed_packages.txt"
    rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux

    if ! dnf repolist enabled | grep -q epel; then
        dnf_install "epel-release"
    fi

#    echo -n "enabling powertools ... "
#    dnf config-manager --enable powertools -y 
#    if [ $? -ne 0 ]; then log_error "failed to enable powertools."; fi 
#    echo "ok"

#    dnf_install dnf-plugins-core
#    dnf config-manager --set-enabled powertools -y 

    # package installation from package list
    while read package; do
        if ! cat logs/installed_packages.txt | grep -q "^${package}$"; then
            dnf_install $package
            echo "$package" >> logs/installed_packages.txt
            sleep 3
        else 
            echo "Package $package already installed ... Skipping"
        fi
    done < <(grep -v '^[[:space:]]*#\|^[[:space:]]*$' "$script_dir/config_files/$package_list")

    start_service chronyd
    enable_service chronyd

#    dnf_install $java 

    start_service atd
    enable_service atd
    
    update_config_file -i "s/^state_software_install=.*/state_software_install=true/" $script_dir/$state_file 
fi

if [ $acronis_install = true ]; then
    if [ $state_acronis_install = false ]; then 
        echo -n "installing Acronis ... "
        $script_dir/software/$acronis_bin -a --skip-registration --id=BackupAndRecoveryAgent
        if [ $? -ne 0 ]; then log_error "installing acronis."; fi
        echo "ok"
    
        update_config_file -i 's/^state_acronis_install=.*/state_acronis_install=true/' $script_dir/$state_file
    fi     

    if [ ! -z $acronis_account ] && [ ! -z $acronis_password ]; then
        echo -n "register acronis agent with username and password ... "
        /usr/lib/Acronis/RegisterAgentTool/RegisterAgent -o register -t cloud -a https://au1-cloud.acronis.com -u "$acronis_account" -p "$acronis_password"
        if [ $? -ne 0 ]; then log_error "registration failed."; fi
        echo "ok"
    elif [ ! -z $acronis_datacentre ] && [ ! -z $acronis_token ]; then
        echo -n "register acronis agent with token ... "
        /usr/lib/Acronis/RegisterAgentTool/RegisterAgent -o register -t cloud -a "$acronis_datacentre" --token "$acronis_token"
        if [ $? -ne 0 ]; then log_error "registration failed."; fi
        echo "ok"
    else
        echo " "
        echo "skipping acronis agent registration. run the following command to register the agent manually."
        echo "    using username and password."
        echo "    sudo /usr/lib/Acronis/RegisterAgentTool/RegisterAgent -o register -t cloud -a https://au1-cloud.acronis.com -u <account> -p <password>"
        echo "    "
        echo "    using registration token."
        echo "    sudo /usr/lib/Acronis/RegisterAgentTool/RegisterAgent -o register -t cloud -a https://au1-cloud.acronis.com --token <token>"
        echo "    "
    fi
fi

change_ownership . "$SUDO_USER" "$SUDO_USER" -R
echo "software installation completed"
