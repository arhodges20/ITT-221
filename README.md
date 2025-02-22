# 🚀 ITT-221 Setup Scripts

This repository contains several automation scripts used to automate prior assignments:  
- **AD-Server-Setup.ps1** → Automates Windows Server setup (AD DS, DNS, DHCP)  
- **ssh_setup.sh** → Installs and configures OpenSSH on Linux  
- **users_and_groups.sh** → Automatically configures any desired number of users and groups, creates directories for each group, assigns permissions, and lets you select which users should be in the sudoers group

## 📌 AD-Server-Setup.ps1 (Windows Server)
### Features:
✅ Configures **network settings** (static IP, DNS)  
✅ Installs **Active Directory, DNS, DHCP** (optional)  
✅ Renames the server and **automates reboots**  

## 🛠 ssh_setup.sh (Linux)
### Features:

✅ Installs OpenSSH
✅ Enables and starts the SSH service
✅ Configures the firewall for SSH

## users_and_groups.sh (Linux)
### Features: 

✅ Creates user groups and assigns users to them
✅ Configures home directories and group-based permissions
✅ Restricts folder access to only assigned group members
✅ Grants sudo access to designated users (optional)

🛠 Notes:

    If re-running AD-Server-Setup.ps1, delete C:\AD_Setup_Progress.txt
    SSH setup works on Ubuntu, Linux Mint, and Debian-based distros
    For VirtualBox, install Guest Additions for better performance
