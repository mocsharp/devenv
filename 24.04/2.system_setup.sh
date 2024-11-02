#!/bin/bash

set -exo pipefail
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Check for sudo
if [[ $EUID -eq 0 ]]; then
   echo "This script must not be run as root"
   exit 1
fi


# Install tools and deps
if [ -f ~/system.setup.done ]; then
   echo "################### Installing apt packages ###################"
   sudo apt-get update
   sudo apt-get install -y \
      tldr ripgrep tree \
      git git-gui tig \
      wget curl unzip apt-transport-https \
      lshw pciutils iperf ncdu \
      ca-certificates gnupg gnupg2 pass pinentry-tty \
      barrier jq flatpak make gdb build-essential \
      libtool autoconf wget openssh-client \
      libssl-dev python3.10-venv python3-pip \
      nautilus-image-converter

   touch ~/system.setup.done
fi


#####################
## OpenConnect VPN ##
#####################
if ! command -v openconnect ; then
   echo "################### Installing OpenConnect VPN ###################"
   sudo apt-get install -y network-manager-openconnect network-manager-openconnect-gnome
else
   echo "################### OpenConnect VPN already installed ###################"
fi


#############
## Flatpak ##
#############
echo "################### Installing Flatpak applications ###################"
sudo apt install -y flatpak

flatpak --system remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if ! flatpak list | grep GIMP; then
   echo "################### Installing GIMP ###################"
   flatpak install --system -y flathub org.gimp.GIMP
fi
if ! flatpak list | grep ExtensionManager; then
   echo "################### Installing ExtensionManager ###################"
   flatpak install --system -y flathub com.mattjakeman.ExtensionManager
fi
if ! flatpak list | grep Slack; then
   echo "################### Installing Slack ###################"
   flatpak install --system -y flathub com.slack.Slack
fi

##################
## Sublime Text ##
##################
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt-get update
sudo apt-get install -y sublime-text

###########
## Brave ##
###########
if ! command -v brave-browser >/dev/null; then
   echo "################### Installing Brave ###################"
   sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
   sudo apt update
   sudo apt install -y brave-browser
else
   echo "################### Brave already installed ###################"
fi

###############
## NOMACHINE ##
###############
arch=$(dpkg --print-architecture)
if ! apt list --installed | grep -q nomachine >/dev/null; then
   echo "################### Installing NoMachine ###################"
   nomachine_platform=$([ "$arch" = "arm64" ] && echo "Arm" || echo "Linux")
   nomachine_dl_page_id=$([ "$arch" = "arm64" ] && echo "118" || echo "5")
   nomachine_version=$(wget "https://downloads.nomachine.com/download/?id=${nomachine_dl_page_id}" -q -O - | grep -A 1 "Version:" | grep -oP "[0-9]+(\.[0-9]+)*_[0-9]+")
   nomachine_ver=$(echo "$nomachine_version" | cut -d . -f1,2)
   nomachine_deb_url="https://download.nomachine.com/download/${nomachine_ver}/${nomachine_platform}/nomachine_${nomachine_version}_${arch}.deb"
   nomachine_deb_tmp="$(mktemp).deb"
   wget -O "$nomachine_deb_tmp" "$nomachine_deb_url"
   sudo apt-get install "$nomachine_deb_tmp" -y
   rm "$nomachine_deb_tmp"
else
   echo "################### NoMachine already installed ###################"
fi

############
## VSCODE ##
############

if ! command -v code >/dev/null; then
   echo "################### Installing VS Code ###################"
   echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
   wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
   sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
   echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
   rm -f packages.microsoft.gpg
   sudo apt-get update
   sudo apt-get install -y code
else
   echo "################### VS Code already installed ###################"
fi

##############################
## NVIDIA CUDA ##
##############################
if ! command -v nvcc >/dev/null; then
   echo "################### Installing NVIDIA CUDA 12.6 Update 1 ###################"
   wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
   sudo dpkg -i cuda-keyring_1.1-1_all.deb
   sudo apt-get update
   sudo apt-get -y install cuda-toolkit-12-6
   sudo apt-get install -y nvidia-open
   rm cuda-keyring_1.1-1_all.deb
else
   echo "################### NVIDIA CUDA already installed ###################"
fi

############
## DOCKER ##
############

# Install if needed
if ! command -v docker >/dev/null; then
   echo "################### Installing Docker ###################"
   # Add Docker's official GPG key:
   sudo apt-get update
   sudo apt-get install ca-certificates curl -y
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc

   # Add the repository to Apt sources:
   echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
   sudo apt-get update

   # Install Docker Engine
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

   # Configure Permissions
   sudo groupadd docker
   sudo usermod -aG docker $USER
else
   echo "################### Docker already installed ###################"
fi

##############################
## NVIDIA Container Toolkit ##
##############################
if ! command -v nvidia-ctk >/dev/null; then
   echo "################### Installing NVIDIA Container Toolkit ###################"
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg &&
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
         sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
else
   echo "################### NVIDIA Container Toolkit already installed ###################"
fi

###########
## SHELL ##
###########
NERD_FONTS_VERSION=v3.2.1
if [ ! -d ~/sc/github/nerd-fonts ]; then
   echo "################### Cloning Nerd Fonts ###################"
   mkdir -p ~/sc/github && pushd ~/sc/github
   git clone --depth 1 --branch $NERD_FONTS_VERSION https://github.com/ryanoasis/nerd-fonts.git

   popd
fi

pushd ~/sc/github/nerd-fonts

echo "################### Checking out tag $NERD_FONTS_VERSION ###################"
if git show-ref -q --heads $NERD_FONTS_VERSION; then
   git checkout $NERD_FONTS_VERSION
else
   git checkout tags/$NERD_FONTS_VERSION -b $NERD_FONTS_VERSION
fi

echo "################### Installing Nerd Fonts ###################"
./install.sh
popd

############
## Ollama ##
############
if ! command -v ollama >/dev/null; then
   echo "################### Installing Ollama ###################"
   curl -fsSL https://ollama.com/install.sh | sh
else
   echo "################### Ollama already installed ###################"
fi



###########
## SHELL ##
###########

# Install recent fish
if ! command -v fish >/dev/null; then
   echo "################### Installing FISH ###################"
   sudo apt-add-repository -y ppa:fish-shell/release-3
   sudo apt-get update
   sudo apt-get install -y fish

   # Make fish default
   echo "################### Making fish default shell ###################"
   fish_path=$(which fish)
   if ! cat /etc/shells | grep $fish_path; then
      echo $fish_path | sudo tee -a /etc/shells
   fi
   sudo chsh -s $fish_path $USER

   # Fisher (fish plugin manager) + Tide (fish prompt)
   echo "################### Installing Fish Plugins ###################"
   fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source \
   && fisher install jorgebucaran/fisher IlanCosman/tide@v6 \
   && tide configure --auto --style=Rainbow --prompt_colors='True color' --classic_prompt_color=Light --show_time='12-hour format' --rainbow_prompt_separators=Round --powerline_prompt_heads=Round --powerline_prompt_tails=Slanted --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Solid --powerline_right_prompt_frame=No --prompt_connection_andor_frame_color=Light --prompt_spacing=Sparse --icons='Many icons' --transient=No"
else
   echo ################### FISH already installed ###################
fi

echo "Reboot your system to apply changes"

