#!/bin/bash

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
sudo raspi-config nonint do_change_locale pt_BR.UTF-8

#Configura Horário ------------------------------- Script deverá ser inserido!
sudo raspi-config nonint do_change_timezone America/Cuiaba
#ou
#sudo raspi-config nonint do_change_timezone America/Sao_Paulo

#Configura layout teclado
sudo raspi-config nonint do_configure_keyboard br

#Configura para desativar o Waylan e utilizar interface X11
sudo raspi-config nonint do_wayland W1

#atualiza a lista apt e atualiza os pacotes do raspiberry
sudo apt update && sudo apt upgrade -y

#Reservado!
#sudo nano /etc/xdg/lxsession/LXDE-pi/autostart
#@chromium-browser --test-type --kiosk --incognito --noerrdialogs --no-context-menu --no-sandbox --disable-infobars --disable-translate --disable-pinch http://192.168.12.247/pesquisa/primavera-leste.php

echo "Passo necessário para configuração do acesso via VNC!"
echo "Insira a senha root para configuração do VNC e a repita novamente"
sudo passwd root 

#Digite a senha root para acesso ao modo root
echo "Digite a senha root que acabou de criar"
su

#Ativa o VNC
sudo raspi-config nonint do_vnc 0
#Define opções de senha e criptografia
sudo printf "Encryption=PreferOff\nAuthentication=VncAuth" > /root/.vnc/config.d/vncserver-x11
read -s -p "Digite a senha do VNC: " senhaVNC
# Definir a senha do VNC para "pleste" e ativar login legado
sudo vncpasswd -service -legacy <<< "$senhaVNC"
echo "Senha do VNC definida e login legado ativado."

# Configurar o RealVNC para iniciar automaticamente no boot
sudo systemctl enable vncserver-x11-serviced
echo "RealVNC configurado para iniciar automaticamente."

echo "Configuração do RealVNC concluída."

echo "Script realizado por Jurandir Moratelli IG @jjmoratelli ;)"
sleep 5
sudo reboot
