#!/bin/bash
backup_path='/home/autoit/config'

while read blk_device; do 
    sfdisk -d /dev/$blk_device > $backup_path/$blk_device.partition.table.backup.txt
done< <(lsblk | grep disk | awk '{print $1}')