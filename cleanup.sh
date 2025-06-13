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


while true; 
do 
    read -p 'Clear password now? (y/n) ' clear_passwd
    if [ ! -z $clear_passwd ] && [ $clear_passwd == "y" ]; then
		sed -i "s/passwd=.*/passwd=''/g" server.properties
		if [ $? -ne 0 ]; then log_error "Failed to update server.properties."; fi
		sed -i "s/password=.*/password=''/g" server.properties
		if [ $? -ne 0 ]; then log_error "Failed to update server.properties."; fi
        break
    elif [ $clear_passwd == "n" ]; then
        echo "Skipped clearing passwords."
        break
    else 
        echo "Invalid option."
    fi
done

while true; 
do 
    read -p 'Remove certificates now? (y/n) ' remove_certificates
    if [ ! -z $remove_certificates ] && [ $remove_certificates == "y" ]; then
        remove_file "certificates/*"
        break
    elif [ $remove_certificates == "n" ]; then
        echo "Skipped remove certificates."
        break
    else 
        echo "Invalid option."
    fi

done