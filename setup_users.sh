#!/bin/bash

generate_nomachine_config() {
  local template_file=$1
  local output_file=$2
  local host=$3
  local port=$4
  local user=$5
  local password=$6
  local scrambled_password escaped_special_char

  echo "Creating the NoMachine config files $output_file ... "
  cp $template_file $output_file
  echo "cp $template_file $output_file"
  if [ $? -ne 0 ]; then log_error "Failed to copy file. "; fi
  sed -i "s/AITHOST/$host/g" "$output_file"
  if [ $? -ne 0 ]; then log_error "Failed to update host."; fi
  sed -i "s/AITPORT/$port/g" $output_file
  if [ $? -ne 0 ]; then log_error "Failed to update port."; fi
  sed -i "s/AITUSER/$user/g" $output_file
  if [ $? -ne 0 ]; then log_error "Failed to update user."; fi
  scrambled_password=$(perl scramble_alg.pl $password)
  if [ $? -ne 0 ]; then log_error "Failed to generate scrambled password."; fi
  escaped_special_char=$(printf '%s\n' "$scrambled_password" | sed -e 's/[\/&]/\\&/g')
  if [ $? -ne 0 ]; then log_error "Failed to escape scrambled password."; fi
  sed -i "s/AITPASSWORD/$escaped_special_char/g" $output_file
  if [ $? -ne 0 ]; then log_error "Failed to update password."; fi
}

add_user() {
  local username=$1
  local skel=$2

  if ! grep -q $username /etc/passwd; then 
    useradd -k $skel $username -m; 
    if [ $? -ne 0 ]; then log_error "Creating the user: $username."; fi
  fi

}

add_system_user() {
  local username=$1
  local skel=$2

  if ! grep -q $username /etc/passwd; then 
    useradd -r -k $skel $username -s /bin/bash -m; 
    if [ $? -ne 0 ]; then log_error "Creating the user: $username."; fi
  fi

}

update_password() {
  local username=$1
  local password=$2

  echo $password | passwd $username --stdin
  if [ $? -ne 0 ]; then log_error "Updating passwords for $username."; fi
}

add_to_group() {
  local username=$1
  local group=$2
  
  if ! id -nG $username | grep -q $group; then
    usermod -aG $group $username
    if [ $? -ne 0 ]; then log_error "Adding $username to $group."; fi
  fi
}