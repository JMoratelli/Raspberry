#!/bin/bash

#atualiza a lista apt e atualiza os pacotes do raspiberry
sudo apt update && sudo apt upgrade -y

#Instala o PiApps
wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash

#Atualiza configuração de audio
sudo raspi-config nonint do_audio 0

#Seleciona nome de host (utilize padrão do machado) configuração futura!
#sudo raspi-config nonint do_hostname <hostname>

#Configura rede (acelera boot)
sudo raspi-config nonint do_boot_wait 0

#Define firefox como padrão
sudo raspi-config nonint do_browser firefox

#Desabilita screenblanking
sudo raspi-config nonint do_blanking 1

#Ativa SSH
sudo raspi-config nonint do_ssh 0

#Configurando Localização Raspiberry
sudo raspi-config nonint do_change_locale pt_BR.UTF-8 UTF-8

#Configura Horário ------------------------------- Script deverá ser inserido!
sudo raspi-config nonint do_change_timezone America/Cuiaba
#ou
#sudo raspi-config nonint do_change_timezone America/Sao_Paulo

#Configura layout teclado
sudo raspi-config nonint do_configure_keyboard br

#Configura para desativar o Waylan e utilizar interface X11
sudo raspi-config nonint do_wayland W1

#Ativa o VNC
sudo raspi-config nonint do_vnc 0

echo "Script realizado por Jurandir Moratelli IG @jjmoratelli ;)"
sleep 5
reboot
#sudo nano /etc/xdg/lxsession/LXDE-pi/autostart
#@chromium-browser --test-type --kiosk --incognito --noerrdialogs --no-context-menu --no-sandbox --disable-infobars --disable-translate --disable-pinch http://192.168.12.247/pesquisa/primavera-leste.php

