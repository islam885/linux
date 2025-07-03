export NCURSES_NO_UTF8_ACS=1
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8 

#!/bin/bash

# === BSPWM INSTALLER FOR ARCH LINUX ===
# Красивый, информативный, удобный, с пошаговым выбором компонентов
# Использует whiptail для меню
# Автоматически устанавливает yay, если его нет
# Подробные комментарии и справка

set -e

# --- Проверка наличия sudo ---
if ! command -v sudo &>/dev/null; then
  whiptail --title "Ошибка: Нет sudo" --msgbox "Для работы скрипта требуется sudo. Установите sudo и повторите попытку." 10 60
  exit 1
fi

# --- Проверка запуска с sudo ---
if [[ $EUID -ne 0 ]]; then
  whiptail --title "Ошибка: Требуется sudo" --msgbox "Запустите скрипт с помощью sudo:\n\nsudo $0\n" 10 60
  exit 1
fi

# --- Проверка свободного места на / (не менее 2 ГБ) ---
FREESPACE=$(df / | awk 'NR==2 {print $4}')
if (( FREESPACE < 2000000 )); then
  whiptail --title "Мало места" --msgbox "На разделе / менее 2 ГБ свободно! Освободите место и повторите попытку." 10 60
  exit 1
fi

# --- Проверка, что не запущен другой пакетный менеджер ---
PKG_MANAGERS=(pamac pacaur trizen paru yay pacman)
for mgr in "${PKG_MANAGERS[@]}"; do
  if pgrep -x "$mgr" &>/dev/null; then
    whiptail --title "Ошибка: Пакетный менеджер" --msgbox "Обнаружен запущенный процесс $mgr. Завершите все пакетные менеджеры перед запуском скрипта." 10 60
    exit 1
  fi
done

# --- Очистка кэша pacman ---
whiptail --title "Очистка кэша" --infobox "Очищаю кэш pacman..." 8 50
sudo pacman -Scc --noconfirm

# --- Базовые проверки и обновления ---
# Проверка подключения к интернету
if ! ping -c 1 archlinux.org &>/dev/null; then
  whiptail --title "Ошибка: Нет интернета" --msgbox "Не удалось подключиться к archlinux.org. Проверьте интернет-соединение и повторите попытку." 10 60
  exit 1
fi

# Синхронизация времени
whiptail --title "Синхронизация времени" --infobox "Синхронизация времени..." 8 50
sudo timedatectl set-ntp true

# Обновление зеркал (reflector)
if ! command -v reflector &>/dev/null; then
  whiptail --title "Установка reflector" --infobox "Устанавливаю reflector для обновления зеркал..." 8 60
  sudo pacman -Sy --noconfirm reflector
fi
whiptail --title "Обновление зеркал" --infobox "Обновление зеркал Arch Linux..." 8 50
sudo reflector --country Russia,Ukraine,Poland,Germany --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Обновление системы
whiptail --title "Обновление системы" --infobox "Обновление системы (pacman -Syu)..." 8 50
sudo pacman -Syu --noconfirm

# --- Цвета для вывода ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Проверка whiptail ---
if ! command -v whiptail &>/dev/null; then
  echo -e "${YELLOW}Устанавливаю whiptail...${NC}"
  sudo pacman -Sy --noconfirm libnewt
fi

# --- Проверка yay ---
if ! command -v yay &>/dev/null; then
  whiptail --title "Установка yay" --infobox "AUR helper yay не найден. Устанавливаю yay..." 8 60
  for pkg in git base-devel; do
    if ! pacman -Qi $pkg &>/dev/null; then
      sudo pacman -Sy --noconfirm $pkg
    fi
  done
  tmpdir=$(mktemp -d)
  chown $SUDO_USER:$SUDO_USER "$tmpdir"
  sudo -u $SUDO_USER bash -c "
    cd '$tmpdir'
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
  rm -rf "$tmpdir"
fi

# --- Функция выбора из списка ---
choose_option() {
  local title="$1"
  local prompt="$2"
  shift 2
  local options=("$@")
  local choice=$(whiptail --title "$title" --menu "$prompt" 18 60 10 "${options[@]}" 3>&1 1>&2 2>&3)
  echo "$choice"
}

# --- Сбор выбора пользователя ---
TERMINAL=$(choose_option "Выбор терминала" "Выберите терминал для установки:" \
  "alacritty" "Alacritty" \
  "kitty" "Kitty" \
  "urxvt" "URxvt" \
  "st" "st (Simple Terminal)" \
  "xterm" "xterm")

EDITOR=$(choose_option "Выбор редактора" "Выберите текстовый редактор:" \
  "neovim" "Neovim" \
  "vim" "Vim" \
  "micro" "Micro" \
  "nano" "Nano")

PANEL=$(choose_option "Выбор панели" "Выберите панель для рабочего стола:" \
  "polybar" "Polybar" \
  "tint2" "Tint2" \
  "xfce4-panel" "XFCE4 Panel" \
  "none" "Без панели")

COMPOSITOR=$(choose_option "Выбор композитора" "Выберите композитор (эффекты):" \
  "picom" "Picom" \
  "xcompmgr" "xcompmgr" \
  "none" "Без композитора")

LOGINMGR=$(choose_option "Менеджер входа" "Выберите менеджер входа (display manager):" \
  "lightdm" "LightDM" \
  "sddm" "SDDM" \
  "ly" "LY (CLI)" \
  "none" "Без менеджера входа")

WALLPAPER=$(choose_option "Фоновая программа" "Выберите программу для обоев:" \
  "feh" "feh" \
  "nitrogen" "nitrogen" \
  "none" "Без обоев")

LAUNCHER=$(choose_option "Лаунчер" "Выберите лаунчер (меню приложений):" \
  "dmenu" "dmenu" \
  "rofi" "rofi" \
  "none" "Без лаунчера")

KEYS=$(choose_option "Клавиши" "Выберите обработчик горячих клавиш:" \
  "sxhkd" "sxhkd" \
  "none" "Без обработчика")

# --- Дополнительные пакеты ---
EXTRA=$(whiptail --title "Дополнительные пакеты" --checklist "Выберите дополнительные пакеты для установки (пробел — выбрать):" 20 70 10 \
  "git" "Git" ON \
  "network-manager-applet" "Network Manager Applet" OFF \
  "pulseaudio" "PulseAudio" OFF \
  "pavucontrol" "PulseAudio Control" OFF \
  "lxappearance" "LXAppearance (темы)" OFF \
  "arandr" "ARandR (мониторы)" OFF \
  "thunar" "Thunar (файловый менеджер)" OFF \
  "neofetch" "Neofetch" OFF \
  "htop" "htop" OFF \
  3>&1 1>&2 2>&3)

# --- Итоговое окно ---
SUMMARY="Терминал: $TERMINAL\nРедактор: $EDITOR\nПанель: $PANEL\nКомпозитор: $COMPOSITOR\nМенеджер входа: $LOGINMGR\nОбои: $WALLPAPER\nЛаунчер: $LAUNCHER\nКлавиши: $KEYS\nДополнительно: $EXTRA"
whiptail --title "Подтверждение" --yesno "Вы выбрали:\n\n$SUMMARY\n\nПродолжить установку?" 20 70
if [[ $? -ne 0 ]]; then
  echo -e "${YELLOW}Установка отменена пользователем.${NC}"
  exit 0
fi

# --- Формируем список пакетов ---
PACKAGES=(bspwm $TERMINAL $EDITOR)
[[ $PANEL != "none" ]] && PACKAGES+=("$PANEL")
[[ $COMPOSITOR != "none" ]] && PACKAGES+=("$COMPOSITOR")
[[ $LOGINMGR != "none" ]] && PACKAGES+=("$LOGINMGR")
[[ $WALLPAPER != "none" ]] && PACKAGES+=("$WALLPAPER")
[[ $LAUNCHER != "none" ]] && PACKAGES+=("$LAUNCHER")
[[ $KEYS != "none" ]] && PACKAGES+=("$KEYS")
# Обработка доп. пакетов (убираем кавычки)
for pkg in $EXTRA; do
  pkg_clean=$(echo $pkg | tr -d '"')
  PACKAGES+=("$pkg_clean")
done
# --- Автоматическая установка хороших шрифтов ---
FONTS=(ttf-dejavu ttf-jetbrains-mono ttf-ubuntu-font-family ttf-font-awesome ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono noto-fonts noto-fonts-cjk noto-fonts-emoji)
PACKAGES+=("${FONTS[@]}")

# --- Установка пакетов ---
echo -e "${GREEN}Устанавливаю выбранные пакеты:${NC} ${PACKAGES[*]}"
yay -S --noconfirm --needed "${PACKAGES[@]}"

# --- Справка после установки ---
whiptail --title "Установка завершена!" --msgbox "BSPWM и выбранные компоненты установлены!\n\n\
- Все необходимые шрифты (включая emoji и nerd-fonts) установлены автоматически\n\
- Для запуска bspwm строка 'exec bspwm' будет автоматически добавлена в ~/.xinitrc\n\
- Настройте sxhkd для горячих клавиш (пример конфигов: /usr/share/doc/bspwm/examples)\n\
- Для автозапуска панели, композитора и прочего — используйте ~/.config/bspwm/bspwmrc\n\
- Приятного использования!" 20 70

# --- Автоматическое добавление exec bspwm в ~/.xinitrc ---
XINITRC="$HOME/.xinitrc"
if [ ! -f "$XINITRC" ]; then
  echo "exec bspwm" > "$XINITRC"
else
  grep -q '^exec bspwm' "$XINITRC" || echo 'exec bspwm' >> "$XINITRC"
fi

systemctl reboot

exit 0
