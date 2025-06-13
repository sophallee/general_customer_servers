#!/bin/bash
# create the disk needed for
script_file=$(basename "$0")
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
script_name=$(echo $script_file | cut -d. -f 1)
cd $script_dir

if [ ! -f "$script_dir/common.sh" ]; then 
    echo "file common.sh not found."; exit 10; 
else
    source $script_dir/common.sh
fi

if [ ! -f $script/state_file ]; then
    cp_file $script_dir/config_files/state_file.template  $script_dir/state_file 
fi

if [ ! -f "$script_dir/variables_check.sh" ]; then log_error "file variables_check.sh not found."; fi
if [ ! -f "$script_dir/software_install.sh" ]; then log_error "file software_install.sh not found."; fi
if [ ! -f "$script_dir/state_file" ]; then log_error "file state_file not found."; fi
if [ ! -f "$script_dir/server.properties" ]; then log_error "file server.properties not found."; fi
if [ ! -f "$script_dir/server.master.properties" ]; then log_error "file server.master.properties not found."; fi

source $script_dir/server.master.properties
source $script_dir/server.properties
source $script_dir/state_file

if ! whoami | grep -q 'root'; then
    log_error "script require elevated privileges. run sudo ./$script_file."
fi

if [ -z "$SUDO_USER" ] || [ "$SUDO_USER" == "root" ] ; then
    log_error "script cannot run in root shell. run sudo ./$script_file as a normal user."
fi

echo "checking variables ... "
shopt -s expand_aliases
source $script_dir/variables_check.sh
source $script_dir/software_install.sh

# script to partition the disk
check_disk_exist "$data_disk"
check_disk_size "$data_lvm1_size"
check_disk_size "$data_lvm2_size"
check_disk_name "$data_lvm1_name"
check_disk_name "$data_lvm2_name"

if ! pvs | grep -q "$data_disk"; then 
	echo -n "adding physical disk $data_disk to lvm ... "
	pvcreate $data_disk
	if [ $? -ne 0 ]; then log_error "adding physical disk $data_disk to lvm"; fi
	echo "ok"
fi 

if ! vgs | grep -q vgdata; then 
	echo -n "creating volume group vgdata ... "
	vgcreate vgdata $data_disk
	if [ $? -ne 0 ]; then log_error "creating volume group vgdata ."; fi
	echo "ok"	
fi

for i in  $(seq 1 $lvm_vol_max); do   
	lvm_name="data_lvm${i}_name"
	lvm_size="data_lvm${i}_size"
	lvm_mnt_point="data_lvm${i}_mnt_point"

	if [ ! -z "${!lvm_name}" ]; then
		if ! lvs | awk '{print $1}' | grep -q "${!lvm_name}$" && ! echo "${!lvm_size}" | grep -q 'FREE'; then
			echo -n "Creating logical volumes: ${!lvm_name} ... "
			lvcreate -n "${!lvm_name}" -L "${!lvm_size}" vgdata
			if [ $? -ne 0 ]; then log_error "Creating ${!lvm_name}."; fi
			echo "OK"	                
		elif ! lvs  | awk '{print $1}'| grep -q "${!lvm_name}$"; then
			echo -n "Creating logical volumes: ${!lvm_name} ... "
			lvcreate -n "${!lvm_name}" -l "${!lvm_size}" vgdata
			if [ $? -ne 0 ]; then log_error "Creating ${!lvm_name}."; fi
			echo "OK"	 
		fi
		if ! mount | awk '{print $3}' | grep -q "${!lvm_mnt_point}$"; then
			create_directory "${!lvm_mnt_point}"
			mkfs.xfs -f /dev/vgdata/"${!lvm_name}"
			if [ $? -ne 0 ]; then log_error "Creating XFS file system for ${!lvm_name}."; fi
			xfs_admin -L "${!lvm_name}" /dev/vgdata/"${!lvm_name}"
			if [ $? -ne 0 ]; then log_error "Creating label for ${!lvm_name}."; fi
		fi

		if ! cat /etc/fstab | awk '{print $1}' | grep -q "/dev/mapper/vgdata-${!lvm_name}$"; then
			echo "/dev/mapper/vgdata-${!lvm_name}  ${!lvm_mnt_point}    xfs    defaults    0    2" | sudo tee -a /etc/fstab
		fi   
	fi
done 

if ! lsblk | grep -q '/home' && [ ! -d '/home-temp' ]; then 
	if ! mount | awk '{print $3}' | grep -q "/dev/mapper/vgdata-home$"; then 
		echo -n "renaming /home to /home-temp ... "
		mv /home /home-temp
		if [ $? -ne 0 ]; then log_error "renaming /home to /home-temp."; fi
		echo "ok"
	fi
fi

create_directory '/home'

systemctl daemon-reload
if [ $? -ne 0 ]; then log_error "failed reload daemon."; fi
echo -n "mounting lvm volumes ... "
mount -a
if [ $? -ne 0 ]; then log_error "mounting lvm volumes."; fi
echo "ok"

if [ -d '/home-temp' ]; then 
	echo -n "moving /home-temp/* /home ... "
	mv /home-temp/* /home
	if [ $? -ne 0 ]; then log_error "moving /home-temp/* /home."; fi
	echo "ok"
	echo -n "removing /home-temp ... "
	rmdir /home-temp
	if [ $? -ne 0 ]; then log_error "removing /home-temp."; fi
	echo "ok"
fi

echo " "      
echo "rebooting server ... "
sleep 5
reboot 