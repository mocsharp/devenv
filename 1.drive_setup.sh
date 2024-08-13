#!/bin/bash

set -o pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check for sudo
if [[ $EUID -eq 0 ]]; then
   echo "This script must not be run as root"
   exit 1
fi

# Setup Data drive
if ! grep -q "/dev/sda1" /etc/fstab; then
   echo ################### Settingup /home ###################
   echo ##### Backing up currnet ~/ to /home/$USER.old...
   mkdir -p /home/$USER.old
   cp -r -f ~/* /home/$USER.old
   echo ###### Updating fstab...
   echo "/dev/sda1       /home   ext4    defaults        0       0" | sudo tee -a /etc/fstab
   echo ###### Rebooting...
   sudo reboot
else
   echo ################### /home already setup ###################
fi