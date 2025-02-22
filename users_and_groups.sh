#!/bin/bash

run_command() {
    eval "$1"
    if [ $? -ne 0 ]; then
        echo "Error executing: $1"
    fi
}

create_group() {
    group_name=$1
    echo "Creating group: $group_name"
    run_command "sudo groupadd $group_name"
    run_command "sudo mkdir -p /mnt/$group_name"
    run_command "sudo chgrp -R $group_name /mnt/$group_name"
    run_command "sudo chmod 770 /mnt/$group_name"
}

create_user() {
    username=$1
    group_name=$2
    echo "Creating user: $username"
    run_command "sudo adduser --force-badname $username"
    run_command "sudo usermod -a -G $group_name $username"
    run_command "sudo mkdir -p /home/$username"
    run_command "sudo chown $username:$username /home/$username"
}

grant_sudo_access() {
    username=$1
    sudoers_file="/etc/sudoers.d/sysadmins"
    echo "Granting sudo access to $username"
    echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee -a $sudoers_file
    sudo chmod 440 $sudoers_file
}

main() {
    read -p "How many groups would you like to create? " num_groups
    declare -a groups
    
    for (( i=1; i<=num_groups; i++ )); do
        read -p "Enter name for group $i: " group_name
        create_group "$group_name"
        groups+=("$group_name")
    done
    
    read -p "How many users would you like to create? " num_users
    for (( i=1; i<=num_users; i++ )); do
        read -p "Enter username for user $i: " username
        echo "Available groups:"
        for idx in "${!groups[@]}"; do
            echo "$((idx+1)). ${groups[idx]}"
        done
        read -p "Select a group for this user (enter number): " group_index
        create_user "$username" "${groups[$((group_index-1))]}"
    done
    
    read -p "Do you want to grant sudo access to any users? (yes/no): " add_sudo
    if [[ "$add_sudo" == "yes" ]]; then
        while true; do
            read -p "Enter username to grant sudo access (or type 'done' to finish): " sudo_user
            if [[ "$sudo_user" == "done" ]]; then
                break
            fi
            grant_sudo_access "$sudo_user"
        done
    fi
    
    echo "Setup complete."
}

main
