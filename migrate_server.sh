#!/bin/bash
script_file=$(basename "$0")
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
script_name=$(echo $script_file | cut -d. -f 1)
cd $script_dir

if [ ! -f "common.sh" ]; then echo "file common.sh not found. aborting."; exit 10; fi
if [ ! -f "$script_dir/webapps.properties" ]; then echo "file pmds.properties not found. aborting."; exit 10; fi
if [ ! -f "$script_dir/webapps.master.properties" ]; then echo "file pmds.master.properties not found. aborting."; exit 10; fi

source common.sh
source "$script_dir/webapps.properties"
source "$script_dir/webapps.master.properties"

echo -n "syncing the hosts file ... "
rsync -aup --progress -e "ssh -p $old_webapps_port -i /home/$SUDO_USER/.ssh/keys/$rsync_key" --rsync-path="sudo rsync" rsync@$old_webapps_hostname:/etc/hosts /etc/hosts.old
if [ $? -ne 0 ]; then log_error "syncing the hosts file."; fi
echo "ok"

echo -n "getting the jetty files ... "
>$script_dir/temp/rsync_exclude.txt

for excluded_item in $(echo "$rsync_exclude" | sed "s/,/ /g"); do
     echo $excluded_item >> $script_dir/temp/rsync_exclude.txt
done

rsync -aup --progress -e "ssh -p $old_webapps_port -i /home/$SUDO_USER/.ssh/keys/$rsync_key" --rsync-path="sudo rsync" rsync@$old_webapps_hostname:$jetty_dir /usr/lib --exclude-from=$script_dir/temp/rsync_exclude.txt
if [ $? -ne 0 ]; then log_error "getting the jetty files."; fi
echo "ok"

if [ ! -L '/jetty' ]; then 
    echo -n "creating /jetty symlink ... "
    ln -s $jetty_dir /jetty
    if [ $? -ne 0 ]; then log_error "creating /jetty symlink."; fi
    echo "ok"
fi

echo "configuring web desktop ... "
for i in $(seq 1 $desktop_instances); do
    mysql_database=mysql_database${i}
	media_library_old=media_library_old${i}
	media_library_folder=media_library_folder${i}
    if [ -z "${!mysql_database}" ]; then
        break
    fi

	echo -n "syncing the medialibrary $i folder ... "
	rsync -aup --progress -e "ssh -p $old_webapps_port -i /home/$SUDO_USER/.ssh/keys/$rsync_key" --rsync-path="sudo rsync" rsync@$old_webapps_hostname:${!media_library_old}/ $media_library_root/${!media_library_folder}
	if [ $? -ne 0 ]; then log_error "syncing the pick folder."; fi
	echo "ok"
done

change_ownership "$media_library_root" pick pick -R
change_permission "$media_library_root" 770

