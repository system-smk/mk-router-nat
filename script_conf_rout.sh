#!/bin/bash
# Script : routeur_usb_ethernet.sh
# Auteur : SMK & Copilot
# Description : Transforme un PC Debian en routeur NAT via USB tethering

echo "=== Configuration du routeur NAT Debian ==="

# Bloc 1 : Choix des interfaces
echo "Entrez le nom de l'interface connectée à Internet (exemple : enx0ef9723bac04 pour USB tethering)"
read -p "Interface Internet : " IFACE_INTERNET

echo "Entrez le nom de l'interface Ethernet vers le second PC (exemple : enp1s0)"
read -p "Interface LAN : " IFACE_LAN

# Bloc 2 : Configuration IP statique
echo "Entrez l'adresse IP statique à attribuer à l'interface LAN (exemple : 192.168.10.1)"
read -p "Adresse IP LAN : " IP_LAN

# Bloc 3 : Plage DHCP
echo "Entrez l'adresse de début de la plage DHCP (exemple : 192.168.10.10)"
read -p "Début DHCP : " DHCP_START

echo "Entrez l'adresse de fin de la plage DHCP (exemple : 192.168.10.50)"
read -p "Fin DHCP : " DHCP_END

echo "Entrez l'adresse du serveur DNS à utiliser (exemple : 8.8.8.8)"
read -p "DNS : " DNS_IP

# Bloc 4 : Configuration de l'interface LAN
sudo ip addr flush dev "$IFACE_LAN"
sudo ip addr add "$IP_LAN/24" dev "$IFACE_LAN"
sudo ip link set "$IFACE_LAN" up

# Bloc 5 : Activation du routage IP
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i '/^#*net.ipv4.ip_forward/s/^#*//;s/=.*/=1/' /etc/sysctl.conf

# Bloc 6 : Configuration du NAT avec iptables
sudo iptables -t nat -A POSTROUTING -o "$IFACE_INTERNET" -j MASQUERADE
sudo iptables -A FORWARD -i "$IFACE_LAN" -o "$IFACE_INTERNET" -j ACCEPT
sudo iptables -A FORWARD -i "$IFACE_INTERNET" -o "$IFACE_LAN" -m state --state RELATED,ESTABLISHED -j ACCEPT

# Bloc 7 : Sauvegarde des règles iptables
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# Bloc 8 : Installation et configuration du serveur DHCP
sudo apt install -y isc-dhcp-server

# Écriture du fichier de configuration DHCP
sudo bash -c "cat > /etc/dhcp/dhcpd.conf <<EOF
subnet ${IP_LAN%.*}.0 netmask 255.255.255.0 {
  range $DHCP_START $DHCP_END;
  option routers $IP_LAN;
  option domain-name-servers $DNS_IP;
}
EOF"

# Définir l'interface utilisée par le serveur DHCP
sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE_LAN\"/" /etc/default/isc-dhcp-server

# Bloc 9 : Redémarrage du service DHCP
sudo systemctl restart isc-dhcp-server

echo "=== Configuration terminée. Le routeur est prêt. ==="
