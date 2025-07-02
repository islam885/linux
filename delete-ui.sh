#!/bin/bash

echo "Удаление графической оболочки (GUI) в Debian..."

# Удаление популярных GUI пакетов
sudo apt purge -y gnome* kde* xfce4* lxde* cinnamon* mate* plasma* \
  xorg* xserver-xorg* lightdm* gdm3* sddm* task-gnome-desktop task-kde-desktop task-desktop

# Очистка зависимостей
sudo apt autoremove -y
sudo apt clean

echo "GUI удалена. Перезагружаем систему..."
sleep 2
sudo reboot
