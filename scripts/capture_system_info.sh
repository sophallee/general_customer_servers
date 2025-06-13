#!/bin/bash
config_path=~/config

> $config_path/system_info.txt
echo "" >> $config_path/system_info.txt
echo "Operating System" >> $config_path/system_info.txt
echo "------------------------------------------------" >> $config_path/system_info.txt
cat /etc/redhat-release >> $config_path/system_info.txt
echo "" >> $config_path/system_info.txt
echo "Memory" >> $config_path/system_info.txt
echo "------------------------------------------------" >> $config_path/system_info.txt
free -h >> $config_path/system_info.txt 
echo "" >> $config_path/system_info.txt
echo "Block devices" >> $config_path/system_info.txt
echo "------------------------------------------------" >> $config_path/system_info.txt
lsblk >> $config_path/system_info.txt
echo "" >> $config_path/system_info.txt
echo "Firmware" >> $config_path/system_info.txt
echo "------------------------------------------------" >> $config_path/system_info.txt
firmware=$( [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS )  
echo $firmware >> $config_path/system_info.txt
echo "" >> $config_path/system_info.txt
echo "CPU" >> $config_path/system_info.txt
echo "------------------------------------------------" >> $config_path/system_info.txt
lscpu >> $config_path/system_info.txt 
echo "" >> $config_path/system_info.txt
