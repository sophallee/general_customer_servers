#!/bin/bash
dnf_install() {
    local package=$1
	echo -n "installing $package ... "

	dnf install "$package" -y
	if [ $? -ne 0 ]; then log_error "installing $package"; fi
	echo "ok"
}

dnf_remove() {
    local package=$1
	echo -n "removing $package ... "
	dnf remove $package -y
	echo $?
	if [ $? -ne 0 ]; then log_error "failed to remove $package."; fi
	echo "ok"
}

install_snap() {
	local counter
	local snap=$1
	echo -n "installing $snap ... "
	while true
	do
		if snap list 2>/dev/null | grep -q $snap; then		
			break
		else
			snap install $snap --classic
			let "counter+=1"
			sleep 1
		fi
		if [ $counter = 30 ]; then
			exit 10
		fi
	done
	echo "ok"	
}
