#!/bin/bash

log_error() {
	echo -e "Error: $1" | /usr/bin/tee -a $ERROR_LOG
	echo "Aborting program ... "
	echo " "
	exit 10
}

create_directory() {
    local directory=$1
 	echo -n "Creating $directory folder ... "
	mkdir -p $directory
	if [ $? -ne 0 ]; then log_error "Creating $directory folder."; fi
	echo "OK"
}

rename_directory() {
    local old_dir=$1
    local new_dir=$2
	echo -n "Renaming $old_dir to $new_dir ... "
	mv $old_dir $new_dir
	if [ $? -ne 0 ]; then log_error "Renaming $old_dir to $new_dir."; fi
	echo "OK"
}

remove_file() {
    local file=$1
	echo -n "Removing $file ... "
	rm -f $file
	if [ $? -ne 0 ]; then log_error "Removing $file."; fi
	echo "OK"
}


remove_directory() {
    local directory=$1
	echo -n "Removing $directory ... "
	rm -rf $directory
	if [ $? -ne 0 ]; then log_error "Removing $directory."; fi
	echo "OK"
}

move_file() {
    local old_file=$1
    local new_file=$2
	echo -n "Moving $old_file to $new_file ... "
	mv $old_file $new_file
	if [ $? -ne 0 ]; then log_error "Moving $old_file to $new_file."; fi
	echo "OK"
}

cp_file() {
    local src_file=$1
    local dest_file=$2
	local option=$3
	echo -n "Copying $src_file to $dest_file ... "
	cp $option $src_file $dest_file
	if [ $? -ne 0 ]; then log_error "Copying $src_file to $dest_file."; fi
	echo "OK"
}

sftp_download_nocheck() {
	local host=$1
	local port=$2
	local username=$3
	local conn_timeout=$4
	local strict_checking=$5
	local identy_file=$6
	local source=$7
	local dest=$8

	echo -n "Downloading $source ... "n
	sftp -oPort="$port" -o "ConnectTimeout $conn_timeout" -o "StrictHostKeyChecking $strict_checking" -o "IdentityFile=$identy_file"  $username@$host:$source $dest 
}

software_download(){
    local package=$1
    local sftp_username=$2
    local sftp_host_internal=$3
    local sftp_port_internal=$4
    local sftp_host_external=$5
    local sftp_port_external=$6
    local sftp_identity=$7
    local sftp_strict=$8
    local sftp_conn_time_out=$9
    local sftp_src=${10}
    local sftp_dest=${11}
    local package_url=${12}
	local wget_options=${13}
    
    if [ ! -f "$sftp_dest/$package" ]; then
		echo -n "Downloading $package ... "
        echo -e "\n"
        echo -n "Downloading from $sftp_host_internal"
		sftp -oPort="$sftp_port_internal" -o "ConnectTimeout $sftp_conn_time_out" -o "StrictHostKeyChecking $sftp_strict" -o "IdentityFile=$sftp_identity"  $sftp_username@$sftp_host_internal:$sftp_src $sftp_dest
        if [ $? -ne 0 ]; then "Download failed from $sftp_host_internal."; else echo OK; fi
    fi

    if [ ! -f "$sftp_dest/$package" ]; then
		echo -n "Downloading $package ... "
        echo -e "\n"
        echo -n "Downloading from $sftp_host_external"
		sftp -oPort="$sftp_port_external" -o "ConnectTimeout $sftp_conn_time_out" -o "StrictHostKeyChecking $sftp_strict" -o "IdentityFile=$sftp_identity"  $sftp_username@$sftp_host_external:$sftp_src $sftp_dest
        if [ $? -ne 0 ] && [ -z "$package_url" ]; then log_error "Download failed from $sftp_host_internal."; else "Download failed from $sftp_host_internal."; fi
    fi

    if [ ! -f "$sftp_dest/$package" ] && [ "$package_url" != "dnf" ]; then
        echo -e "\n"
        echo -n "Downloading from $package_url"
		wget $wget_options -O "$sftp_dest/$package" $package_url
        if [ $? -ne 0 ]; then log_error "Download failed from $package_url."; else echo "OK"; fi
	elif [ ! -f "$sftp_dest/$package" ] && [ "$package_url" == "dnf" ]; then
		log_error "Package download failed for $package."
    fi	
}

file_checksum() {
	local file=$1
	local remote_file_checksum=$2
	local local_file_checksum=$(md5sum "$file"| awk '{print $1}')
	
	if [ "$local_file_checksum" != "$remote_file_checksum" ]; then 
		log_error "Checksum failed for $file." 
	fi
}

file_sha256sum() {
	local file=$1
	local remote_file_checksum=$2
	local local_file_checksum=$(sha256sum "$file"| awk '{print $1}')

	if [ "$local_file_checksum" != "$remote_file_checksum" ]; then 
		log_error "Checksum failed for $file." 
	fi
}

start_service() {
	local service=$1
	echo -n "Starting $service ... "
	systemctl start $service
	if [ $? -ne 0 ]; then log_error "Failed to start $service"; fi
	echo "OK"
}

stop_service() {
	local service=$1
	echo -n "Stoping $service ... "
	systemctl stop $service
	if [ $? -ne 0 ]; then log_error "Failed to stop $service"; fi
	echo "OK"
}

restart_service() {
	local service=$1
	echo -n "Restarting $service ... "
	systemctl restart $service
	if [ $? -ne 0 ]; then log_error "Failed to restart $service"; fi
	echo "OK"
}

enable_service() {
	local service=$1
	echo -n "Enabling $service ... "
	systemctl enable $service
	if [ $? -ne 0 ]; then log_error "Failed to enable $service"; fi
	echo "OK"
}

extract_tarball() {
    local archive=$1
	local dest=$2
	local options=$3
	if [ -z "$options" ]; then options='-xzvf'; fi
	echo -n "Extracting $archive ... "
	tar $options $archive -C $dest 
	if [ $? -ne 0 ]; then log_error "Extracting $archive."; fi
	echo "OK"
}

alternatives_install() {
    local alt_symlink=$1
    local alt_name=$2
    local alt_path=$3
    local alt_priority=$4
	echo -n "Creating alternative: alternatives --install $alt_symlink $alt_name $alt_path $alt_priority ... "
	alternatives --install $alt_symlink $alt_name $alt_path $alt_priority
	if [ $? -ne 0 ]; then log_error "Creating alternative: alternatives --install $alt_symlink $alt_name $alt_path $alt_priority ... "; fi
	echo "OK"
}

add_hostname_to_etc_hosts() {
	ip_addr=$1
	hostname=$2
	hostname_fqdn=$3

    if [ ! -z $ip_addr ] && ! grep -q "$hostname" /etc/hosts; then 
        echo "Adding $hostname $hostname_fqdn into /etc/hosts"
        sed -i "/^::1/a $ip_addr\t$hostname $hostname_fqdn" /etc/hosts
        if [ $? -ne 0 ]; then log_error "Adding host entry for $hostname $hostname_fqdn"; fi    
    fi

}

update_config_file() {
	local flag=$1
	local expression=$2
	local file=$3
	
	echo -n "Updating $file with expression $expression ... "
	sed "$flag" "$expression" "$file"
	if [ $? -ne 0 ]; then log_error "Updating $file with expression $expression."; fi
	echo "OK"
}

change_permission() {
    local file=$1
    local permission=$2
	local flags=$3
	echo -n "Setting permission $permission on $file  ... "
	chmod $flags $permission $file
	if [ $? -ne 0 ]; then log_error "Setting permission $permission on $file."; fi
	echo "OK"
}

change_ownership() {
    local file=$1
    local user=$2
	local group=$3
	local flags=$4
	echo -n "Changing ownership on $file ... "
	chown $flags $user:$group $file
	if [ $? -ne 0 ]; then log_error "Changing ownerstip on $file."; fi
	echo "OK"
}



firewall_add_port() {
	local port=$1
	local protocol=$2

	echo -n "Adding port $port protocol $protocol to firewall rule ... "
	if ! firewall-cmd --list-all | grep -q "$port/$protocol"; then
		firewall-cmd --permanent --add-port=$port/$protocol
		if [ $? -ne 0 ]; then log_error "Adding port $port protocol $protocol to firewall rule."; fi
		echo "OK"
	else
		echo "Firewall rule exists. Skipping"
	fi
}

firewall_add_service() {
	local service=$1

	echo -n "Adding service $service to firewall rule ... "
	if ! firewall-cmd --list-all | grep -q "$service \|$service$"; then
		firewall-cmd --permanent --add-service=$service
		if [ $? -ne 0 ]; then log_error "Adding service $service to firewall rule."; fi
		echo "OK"
	else
		echo "Firewall rule exists. Skipping"
	fi
}

firewall_reload() {
	echo -n "Reloading firewall ... "
	firewall-cmd --reload > /dev/null 2>&1
	if [ $? -ne 0 ]; then log_error "Reloading firewall."; fi
	echo "OK"
}