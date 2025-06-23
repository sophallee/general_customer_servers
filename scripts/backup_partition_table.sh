#!/bin/bash
backup_path='~/config'

if [ ! -d $backup_path ]; then
    mkdir $backup_path
fi

while read blk_device; do 
    sudo sfdisk -d /dev/$blk_device | sudo tee $backup_path/$blk_device.partition.table.backup.txt
done< <(lsblk | grep disk | awk '{print $1}')