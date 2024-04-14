#!/bin/bash

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "Please run this script as a non-root user." >&2
        exit 1
    fi
}

install_openssh() {
    if ! command -v sshd &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y openssh-server
    else
        echo "OpenSSH Server is already installed."
    fi
}

restart_ssh_service() {
    sudo systemctl restart sshd
}

add_to_path() {
    local path_to_add=$1
    if [[ ":$PATH:" != *":$path_to_add:"* ]]; then
        echo "export PATH=$PATH:$path_to_add" >> ~/.bashrc
        source ~/.bashrc
        echo "Added $path_to_add to PATH."
    else
        echo "$path_to_add is already in PATH."
    fi
}

check_root

install_openssh

add_to_path "$HOME/bin"

guard_url="https://raw.githubusercontent.com/prochy-exe/playground/main/command_ssh_guard.sh"
zzz_url="https://raw.githubusercontent.com/prochy-exe/playground/main/zzz.sh"
off_url="https://raw.githubusercontent.com/prochy-exe/playground/main/off.sh"
path_to_bin="$HOME/bin"

wget -O "$path_to_bin/command_ssh_guard" "$guard_url"
wget -O "$path_to_bin/zzz" "$zzz_url"
wget -O "$path_to_bin/off" "$off_url"

chmod +x "$path_to_bin/command_ssh_guard" "$path_to_bin/zzz" "$path_to_bin/off"

sshd_config_path="/etc/ssh/sshd_config"
if [ -f "$sshd_config_path" ]; then
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$sshd_config_path"
    sed -i 's/^#PubkeyAuthentication no/PubkeyAuthentication yes/' "$sshd_config_path"
else
    echo "sshd_config not found at $sshd_config_path."
fi

auth_keys_path="$HOME/.ssh/authorized_keys"
if [ ! -f "$auth_keys_path" ]; then
    touch "$auth_keys_path"
    echo "Created authorized_keys"
fi
public_key="$1"
echo "command=\"command_ssh_guard\" $public_key" >> "$auth_keys_path"
echo "Appended SSH key to administrators_authorized_keys"

restart_ssh_service