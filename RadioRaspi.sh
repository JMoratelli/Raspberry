#!/bin/bash

#Realiza a instalação dos emuladores do Raspberry Wine
version=9.22

# https://github.com/raspberrypi/bookworm-feedback/issues/107
PAGE_SIZE="$(getconf PAGE_SIZE)"
if [[ "$PAGE_SIZE" == "16384" ]]; then
  #switch to 4K pagesize kernel
  if [ -f /boot/config.txt ] || [ -f /boot/firmware/config.txt ]; then
    if [ -f /boot/firmware/config.txt ]; then
      boot_config="/boot/firmware/config.txt"
    elif [ -f /boot/config.txt ]; then
      boot_config="/boot/config.txt"
    fi
    text="Raspberry Pi 5 PiOS images ship by default with a 16K PageSize Linux Kernel.
This kernel causes incompatibilities with some software including Wine https://github.com/raspberrypi/bookworm-feedback/issues/107

Would you like to automatically switch to a 4K PageSize Linux Kernel?"
    userinput_func "$text" "No, keep 16K PageSize Kernel and Exit" "Yes, switch to 4K PageSize Kernel"
    if [ "$output" == "No, keep 16K PageSize Kernel and Exit" ]; then
      error "User error: Your current running kernel is built with 16K PageSize and is incompatible with Wine (x64) with Box64. You must switch to a 4K PageSize kernel (and chose to not do so automatically) before installing Wine (x64)."
    fi
    echo "" | sudo tee --append $boot_config >/dev/null
    echo "[pi5]" | sudo tee --append $boot_config >/dev/null
    echo "kernel=kernel8.img" | sudo tee --append $boot_config >/dev/null
    echo -e "The 4K PageSize Kernel has been enabled by adding 'kernel=kernel8.img' to $boot_config\nPlease reboot now and install the Wine (x64) app again."
    sleep infinity
  else
    error "User error (reporting allowed): Your current running kernel is built with 16K PageSize and is incompatible with Wine (x64) with Box64. Changing kernels automatically cannot be done since no /boot/config.txt or /boot/firmware/config.txt file was found."
  fi
fi

# Hangover conflicts with Wine
"${DIRECTORY}/manage" uninstall "Wine (x64)"
if package_installed fonts-wine ;then
  sudo apt purge fonts-wine -y || exit 1
fi
if package_installed libwine ;then
  sudo apt purge libwine -y || exit 1
fi

if [ "$__os_codename" == "bullseye" ]; then
  ho_distro="debian11"
elif [ "$__os_codename" == "bookworm" ]; then
  ho_distro="debian12"
elif [ "$__os_codename" == "focal" ]; then
  ho_distro="ubuntu2004"
elif [ "$__os_codename" == "jammy" ]; then
  ho_distro="ubuntu2204"
elif [ "$__os_codename" == "noble" ]; then
  ho_distro="ubuntu2404"
else
  error "User error: You are not using a supported Pi-Apps distribution."
fi

cd /tmp || error "Could not move to /tmp folder"
wget https://github.com/AndreRH/hangover/releases/download/hangover-${version}/hangover_${version}_${ho_distro}_${__os_codename}_arm64.tar || error "Failed to download Hangover!"
tar -xf hangover_${version}_${ho_distro}_${__os_codename}_arm64.tar || error "Failed to extract Hangover!"
rm -f hangover_${version}_${ho_distro}_${__os_codename}_arm64.tar
install_packages /tmp/hangover-libarm64ecfex_${version}_arm64.deb /tmp/hangover-libqemu_${version}~${__os_codename}_arm64.deb /tmp/hangover-libwow64fex_${version}_arm64.deb /tmp/hangover-wine_${version}~${__os_codename}_arm64.deb || exit 1
rm -f ./hangover-libarm64ecfex_${version}_arm64.deb ./hangover-libqemu_${version}~${__os_codename}_arm64.deb ./hangover-libwow64fex_${version}_arm64.deb ./hangover-wine_${version}~${__os_codename}_arm64.deb

cat << EOF | sudo tee /usr/local/bin/generate-hangover-prefix >/dev/null
#!/bin/bash
echo

#set up functions
$(declare -f error)
$(declare -f status)
$(declare -f status_green)
$(declare -f warning)
$(declare -f userinput_func)

if [ "\$(id -u)" == 0 ];then
  error "Please don't run this script with sudo."
fi

if [ -z "\$WINEPREFIX" ];then
  WINEPREFIX="\$HOME/.wine"
fi
export WINEPREFIX

if [ -f "\$WINEPREFIX/system.reg" ];then
  registry_exists=true
else
  registry_exists=false
fi

export WINEDEBUG=-virtual #hide harmless memory errors

if [ -e "\$WINEPREFIX" ];then
  status "Checking Wine prefix at \$WINEPREFIX..."
  echo "To choose another prefix, set the WINEPREFIX variable."
  echo -n "Waiting 5 seconds... "
  sleep 5
  echo
  # check for existance of incompatible prefix (see server_init_process https://github.com/wine-mirror/wine/blob/884cff821481b4819f9bdba455217bd5a3f97744/dlls/ntdll/unix/server.c#L1544-L1670)
  # Boot wine and check for errors (make fresh wineprefix)
  output="\$(set -o pipefail; wine wineboot 2>&1 | tee /dev/stderr; )" #this won't display any dialog boxes that require a button to be clicked
  if [ "\$?" != 0 ]; then
    text="Your previously existing Wine prefix failed with an error (see terminal log).

Would you like to remove and regenerate your Wine prefix? Doing so will delete anything you may have installed into your Wine prefix."
    userinput_func "\$text" "No, keep broken Wine prefix and Exit" "Yes, delete and regenerate Wine prefix"
    if [ "\$output" == "No, keep broken Wine prefix and Exit" ]; then
      error "User error: Your current Wine prefix caused Wine to error on launch and you chose to keep it. Manually correct your Wine prefix before installing or updating Wine (x64)."
    fi
    warning "Your previously existing Wine prefix failed with an error (see above). You chose to remove it and so it will be re-generated."
    rm -rf "\$WINEPREFIX"
    registry_exists=false
    wine wineboot #this won't display any dialog boxes that require a button to be clicked
  fi
  #wait until above process exits
  sleep 2
  while [ ! -z "\$(pgrep -i 'wine C:')" ];do
    sleep 1
  done
else
  status "Generating Wine prefix at \$WINEPREFIX..."
  echo "To choose another prefix, set the WINEPREFIX variable."
  echo "Waiting 5 seconds..."
  sleep 5
  # Boot wine (make fresh wineprefix)
  wine wineboot #this won't display any dialog boxes that require a button to be clicked
  #wait until above process exits
  sleep 2
  while [ ! -z "\$(pgrep -i 'wine C:')" ];do
    sleep 1
  done
fi

if [ "\$registry_exists" == false ];then
status "Making registry changes..."
TMPFILE="\$(mktemp)" || exit 1
echo 'REGEDIT4' > \$TMPFILE

echo "  - Disabling Wine mime associations" #see https://askubuntu.com/a/400430

echo '
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunServices]
"winemenubuilder"="C:\\\\windows\\\\system32\\\\winemenubuilder.exe -r"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunServices]
"winemenubuilder"="C:\\\\windows\\\\system32\\\\winemenubuilder.exe -r"' >> \$TMPFILE

wine regedit \$TMPFILE

rm -f \$TMPFILE
fi #end of if statement that only runs if this script was started when there was no wine registry
true
EOF

sudo chmod +x /usr/local/bin/generate-hangover-prefix
/usr/local/bin/generate-hangover-prefix || exit 1

#Realiza Instalação do Box 64
if dpkg -l box64 &>/dev/null ;then
  sudo apt purge -y --allow-change-held-packages box64*
fi

add_external_repo "box64" "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" "https://Pi-Apps-Coders.github.io/box64-debs/debian" "./" || exit 1

apt_update
if [ $? != 0 ]; then
  rm_external_repo "box64"
  error "Failed to perform apt update after adding box64 repository."
fi

# obtain SOC_ID
get_model
if [[ "$SOC_ID" == "tegra-x1" ]] || [[ "$SOC_ID" == "tegra-x2" ]]; then
  install_packages box64-tegrax1 || exit 1
elif [[ "$SOC_ID" == "rk3399" ]]; then
  install_packages box64-rk3399 || exit 1
elif [[ "$SOC_ID" == "bcm2711" ]]; then
  install_packages box64-rpi4arm64 || exit 1
elif [[ "$SOC_ID" == "bcm2837" ]]; then
  install_packages box64-rpi3arm64 || exit 1
elif cat /proc/cpuinfo | grep -q aes; then
  warning "There is no box64 pre-build for your device $SOC_ID $model"
  warning "Installing the generic arm box64 build as a fallback (crypto extensions enabled)"
  install_packages box64-generic-arm || exit 1
else
  warning "There is no box64 pre-build for your device $SOC_ID $model"
  warning "Installing the RPI4 tuned box64 build as a fallback (no crypto extensions enabled)"
  install_packages box64-rpi4arm64 || exit 1
fi

#Realiza Instalação do Box x86

if [ -z "$__cpu_op_mode_32" ]; then
  error "User error: Box86 requires a CPU capable of executing ARM32 instructions. Your CPU is only capable of executing ARM64 instructions."
fi

PAGE_SIZE="$(getconf PAGE_SIZE)"
if [[ "$PAGE_SIZE" == "16384" ]]; then
  #switch to 4K pagesize kernel
  if [ -f /boot/config.txt ] || [ -f /boot/firmware/config.txt ]; then
    if [ -f /boot/firmware/config.txt ]; then
      boot_config="/boot/firmware/config.txt"
    elif [ -f /boot/config.txt ]; then
      boot_config="/boot/config.txt"
    fi
    text="Raspberry Pi 5 PiOS images ship by default with a 16K PageSize Linux Kernel.
This kernel causes incompatibilities with some software including Box86 https://github.com/raspberrypi/bookworm-feedback/issues/107

Would you like to automatically switch to a 4K PageSize Linux Kernel?"
    userinput_func "$text" "No, keep 16K PageSize Kernel and Exit" "Yes, switch to 4K PageSize Kernel"
    if [ "$output" == "No, keep 16K PageSize Kernel and Exit" ]; then
      error "User error: Your current running kernel is built with 16K PageSize and is incompatible with Box86. You must switch to a 4K PageSize kernel (and chose to not do so automatically) before installing Box86."
    fi
    echo "" | sudo tee --append $boot_config >/dev/null
    echo "[pi5]" | sudo tee --append $boot_config >/dev/null
    echo "kernel=kernel8.img" | sudo tee --append $boot_config >/dev/null
    echo -e "The 4K PageSize Kernel has been enabled by adding 'kernel=kernel8.img' to $boot_config\nPlease reboot now and install the Box86 app again."
    sleep infinity
  else
    error "User error (reporting allowed): Your current running kernel is built with 16K PageSize and is incompatible with Box86. Changing kernels automatically cannot be done since no /boot/config.txt or /boot/firmware/config.txt file was found."
  fi
fi

function check-armhf() {
	ARMHF="$(dpkg --print-foreign-architectures | grep "armhf")"
}

#add armhf architecture (multiarch)
check-armhf
if [[ "$ARMHF" == *"armhf"* ]]; then
  echo "armhf arcitecture already added..."
else
  sudo dpkg --add-architecture armhf
  check-armhf
  if [[ "$ARMHF" != *"armhf"* ]]; then
    error "armhf architecture should be added by now, but it isn't!"
  fi
fi

if dpkg -l box86 &>/dev/null ;then
  sudo apt purge -y --allow-change-held-packages box86*
fi

#install box86 dependencies
unset rpi_arm_userspace
# only install the libraspberrypi0 arm32 package if the user already has the libraspberrypi0 arm64 package installed
if package_installed libraspberrypi0 ; then
  rpi_arm_userspace="libraspberrypi0:armhf"
fi

unset mesa_va_drivers
# only install the mesa-va-drivers arm32 package if the user already has the mesa-va-drivers arm64 package installed
if package_installed mesa-va-drivers ; then
  mesa_va_drivers="mesa-va-drivers:armhf"
fi

if [[ ! -z "$__os_original_id" ]]; then
  error "User error: Box86 cannot be installed on $__os_original_desc. Please use any official Ubuntu Flavor, Debian, or PiOS/Raspbian Bullseye."
elif [[ "$__os_codename" == "buster" ]]; then
  error "User error: Box86 cannot be installed on $__os_desc. Please use any official Ubuntu Flavor, Debian, or PiOS/Raspbian Bullseye."
fi

# libsdl2-mixer-2.0-0:armhf NOT included since it depends on libopusfile0 on newer distros (buster+ and focal+) which is NOT multiarch compatible

box86_depends=()
if package_available libcal3d12t64:armhf; then
  box86_depends+=('libcal3d12t64:armhf')
else
  box86_depends+=('libcal3d12v5:armhf')
fi
if package_available libcups2t64:armhf; then
  box86_depends+=('libcups2t64:armhf')
else
  box86_depends+=('libcups2:armhf')
fi
if package_available libcurl4t64:armhf; then
  box86_depends+=('libcurl4t64:armhf')
else
  box86_depends+=('libcurl4:armhf')
fi
if package_available libgtk2.0-0t64:armhf; then
  box86_depends+=('libgtk2.0-0t64:armhf')
else
  box86_depends+=('libgtk2.0-0:armhf')
fi
if package_available libgtk-3-0t64:armhf; then
  box86_depends+=('libgtk-3-0t64:armhf')
else
  box86_depends+=('libgtk-3-0:armhf')
fi
if package_available libpng16-16t64:armhf; then
  box86_depends+=('libpng16-16t64:armhf')
else
  box86_depends+=('libpng16-16:armhf')
fi
if package_available libsmpeg0t64:armhf; then
  box86_depends+=('libsmpeg0t64:armhf')
else
  box86_depends+=('libsmpeg0:armhf')
fi
if package_available libssl3t64:armhf; then
  box86_depends+=('libssl3t64:armhf')
elif package_available libssl3:armhf; then
  box86_depends+=('libssl3:armhf')
else
  box86_depends+=('libssl1.1:armhf')
fi

install_packages "${box86_depends[@]}" libc6:armhf libstdc++6:armhf \
  libx11-6:armhf \
  libgdk-pixbuf2.0-0:armhf \
  libjpeg62:armhf \
  libopenal1:armhf osspd:armhf libvorbisfile3:armhf \
  libudev1:armhf \
  libsdl2-2.0-0:armhf libsdl2-image-2.0-0:armhf libsdl2-net-2.0-0:armhf libsdl2-ttf-2.0-0:armhf \
  libsdl1.2debian:armhf libsdl-mixer1.2:armhf libsdl-image1.2:armhf libsdl-net1.2:armhf libsdl-sound1.2:armhf libsdl-ttf2.0-0:armhf \
  libssh-gcrypt-4:armhf \
  libgssapi-krb5-2:armhf libkrb5-3:armhf \
  $rpi_arm_userspace $mesa_va_drivers libegl1:armhf libglx-mesa0:armhf libgl1:armhf libgles2:armhf

add_external_repo "box86" "https://pi-apps-coders.github.io/box86-debs/KEY.gpg" "https://Pi-Apps-Coders.github.io/box86-debs/debian" "./" || exit 1

apt_update
if [ $? != 0 ]; then
  rm_external_repo "box86"
  error "Failed to perform apt update after adding box86 repository."
fi

# obtain SOC_ID
get_model
if [[ "$SOC_ID" == "tegra-x1" ]] || [[ "$SOC_ID" == "tegra-x2" ]]; then
  install_packages box86-tegrax1:armhf || exit 1
elif [[ "$SOC_ID" == "rk3399" ]]; then
  install_packages box86-rk3399:armhf || exit 1
elif [[ "$SOC_ID" == "bcm2711" ]]; then
  install_packages box86-rpi4arm64:armhf || exit 1
elif [[ "$SOC_ID" == "bcm2837" ]]; then
  install_packages box86-rpi3arm64:armhf || exit 1
elif cat /proc/cpuinfo | grep -q aes; then
  warning "There is no box86 pre-build for your device $SOC_ID $model"
  warning "Installing the generic arm box86 build as a fallback (crypto extensions enabled)"
  install_packages box86-generic-arm:armhf || exit 1
else
  warning "There is no box86 pre-build for your device $SOC_ID $model"
  warning "Installing the RPI4 tuned box86 build as a fallback (no crypto extensions enabled)"
  install_packages box86-rpi4arm64:armhf || exit 1
fi
