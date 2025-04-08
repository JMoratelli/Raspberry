# Raspberry

Instalação Raspi

Acesse via SSH
Primeiro execute esse comando, para liberar conexão com a internet
sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.12.1 192.168.2.1" && sudo nmcli connection up "Wired connection 1" 

Em seguida esse, para iniciar ativação do raspibery.
wget https://raw.githubusercontent.com/JMoratelli/Raspberry/refs/heads/main/RaspiConfig -O raspi_config.sh && chmod +x raspi_config.sh && ./raspi_config.sh
