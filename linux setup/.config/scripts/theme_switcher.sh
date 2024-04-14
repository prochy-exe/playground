#!/bin/bash
time=$(date +%k%M)

if [[ "$time" -ge 2100 || "$time" -le 759 ]];then
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    kitten themes --reload-in=all GitHub Dark
    sed -i.bak 's/light/dark/g' /home/prochy/.config/alacritty/alacritty.toml
else
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    kitten themes --reload-in=all GitHub Light
    sed -i.bak 's/dark/light/g' /home/prochy/.config/alacritty/alacritty.toml
fi
