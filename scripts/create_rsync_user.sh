#!/bin/bash
username='rsync'
password="$(tr -dc 'A-Za-z0-9!@#$%^&()-+~' < /dev/urandom | head -c 32)"
public_key=''
days_until_expiration=30

expiry_date=$(date -d "+$days_until_expiration days" '+%Y-%m-%d')

script_file=$(basename "$0")
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
script_name=$(echo $script_file | cut -d. -f 1)
cd $script_dir

log_error() {
	echo -e "error: $1"
	echo "aborting program ... "
	echo " "
	exit 10
}

create_directory() {
    local directory=$1
 	echo -n "creating $directory ... "
	mkdir -p $directory
	if [ $? -ne 0 ]; then log_error "creating $directory."; fi
	echo "ok"
}

remove_directory() {
    local directory=$1
	echo -n "removing $directory ... "
	rm -rf $directory
	if [ $? -ne 0 ]; then log_error "removing $directory."; fi
	echo "ok"
}

change_permission() {
    local file=$1
    local permission=$2
	local flags=$3
	echo -n "setting permission $permission on $file  ... "
	chmod $flags $permission $file
	if [ $? -ne 0 ]; then log_error "setting permission $permission on $file."; fi
	echo "ok"
}

change_ownership() {
    local file=$1
    local user=$2
	local group=$3
	local flags=$4
	echo -n "changing ownership on $file ... "
	chown $flags $user:$group $file
	if [ $? -ne 0 ]; then log_error "changing ownerstip on $file."; fi
	echo "ok"
}

add_user() {
  local username=$1
  local skel=$2

  if ! grep -q $username /etc/passwd; then 
    useradd -k $skel $username -m; 
    if [ $? -ne 0 ]; then log_error "creating the user: $username."; fi
  fi

}

update_password() {
  local username=$1
  local password=$2

  echo $password | passwd $username --stdin
  if [ $? -ne 0 ]; then log_error "updating passwords for $username."; fi
}

while true
do 
	if [ -z "$public_key" ]; then
	    read -p "Enter a public key for the rsync user: " public_key
	else
        break
	fi
done

add_user "$username" "/etc/skel"
update_password "$username" "$password"
create_directory "/home/$username/.ssh"
change_permission "/home/$username/.ssh" "700"
echo "adding public key"
echo "$public_key" | tee "/home/$username/.ssh/authorized_keys"
change_permission "/home/$username/.ssh/authorized_keys" "600"
chage -E $expiry_date $username
change_ownership "/home/$username/.ssh" "$username" "$username" "-R"

echo "updating visudo for rsync"
if grep -q '^#includedir /etc/sudoers.d' /etc/sudoers; then
    echo "Cmnd_Alias RSYNC = /usr/bin/rsync" | tee /etc/sudoers.d/sudoers-cmnd-rsync
    echo " " | tee -a /etc/sudoers.d/sudoers-cmnd-rsync
    echo "$username    ALL=(ALL)   NOPASSWD:RSYNC" | tee -a /etc/sudoers.d/sudoers-cmnd-rsync
else
    echo "includedir might not be supported on your os"
    echo "add the users manually"
fi

