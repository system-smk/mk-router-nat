#!/bin/bash
# Script : routeur_usb_ethernet.sh
# Auteur : SMK & Copilot & Gemini & Claude
# Description : Transforme un PC Debian en routeur NAT via USB tethering


# S'arrêter immédiatement si une commande échoue (bonne pratique)
set -e

echo "=== Démarrage de la Configuration du routeur NAT Debian ==="

# ------------------------------------------------------------------
# Bloc 1 : Choix des interfaces et des IPs
# ------------------------------------------------------------------

echo "--- 1/9 : Saisie des interfaces et des adresses IP ---"

read -p "Entrez le nom de l'interface connectée à Internet (ex: enx0ef9723bac04) : " IFACE_INTERNET
read -p "Entrez le nom de l'interface LAN vers le second PC (ex: enp1s0) : " IFACE_LAN
read -p "Entrez l'adresse IP statique à attribuer à l'interface LAN (ex: 192.168.10.1) : " IP_LAN
read -p "Entrez l'adresse de début de la plage DHCP (ex: 192.168.10.10) : " DHCP_START
read -p "Entrez l'adresse de fin de la plage DHCP (ex: 192.168.10.50) : " DHCP_END
read -p "Entrez l'adresse du serveur DNS à utiliser (ex: 8.8.8.8) : " DNS_IP

# ------------------------------------------------------------------
# Bloc 2 : Configuration de l'interface LAN
# ------------------------------------------------------------------

echo "--- 2/9 : Configuration de l'interface LAN ($IFACE_LAN) ---"

# ⚠️ Amélioration : Vérification de l'existence des interfaces
if [ ! -d "/sys/class/net/$IFACE_LAN" ] || [ ! -d "/sys/class/net/$IFACE_INTERNET" ]; then
    echo "ERREUR : Une des interfaces spécifiées n'existe pas. Veuillez vérifier les noms." >&2
    exit 1
fi

sudo ip addr flush dev "$IFACE_LAN"
sudo ip addr add "$IP_LAN/24" dev "$IFACE_LAN"
sudo ip link set "$IFACE_LAN" up

# ------------------------------------------------------------------
# Bloc 3 : Activation du routage IP (IP Forwarding)
# ------------------------------------------------------------------

echo "--- 3/9 : Activation du Routage IP ---"

# Activation immédiate
sudo sysctl -w net.ipv4.ip_forward=1
# Rendre persistant dans sysctl.conf (Amélioration : s'assurer qu'il est décommenté et mis à 1)
sudo sed -i '/^#*net.ipv4.ip_forward/s/^#*//;s/=.*/=1/' /etc/sysctl.conf

# ------------------------------------------------------------------
# Bloc 4 : Configuration et Nettoyage du NAT avec iptables
# ------------------------------------------------------------------

echo "--- 4/9 : Configuration du NAT (Masquerade) ---"

# ⚠️ Amélioration : Nettoyage des règles iptables existantes pour éviter la duplication
echo "Nettoyage des règles iptables existantes..."
sudo iptables -t nat -F  # Flush (supprimer) toutes les règles de la table NAT
sudo iptables -F        # Flush toutes les règles de la table Filter
sudo iptables -X        # Supprimer les chaînes personnalisées

# Règles NAT
sudo iptables -t nat -A POSTROUTING -o "$IFACE_INTERNET" -j MASQUERADE

# Règles de FORWARD (autoriser le trafic LAN -> Internet)
sudo iptables -A FORWARD -i "$IFACE_LAN" -o "$IFACE_INTERNET" -j ACCEPT
sudo iptables -A FORWARD -i "$IFACE_INTERNET" -o "$IFACE_LAN" -m state --state RELATED,ESTABLISHED -j ACCEPT

# ------------------------------------------------------------------
# Bloc 5 : Sauvegarde des règles iptables
# ------------------------------------------------------------------

echo "--- 5/9 : Sauvegarde des règles iptables pour persistance ---"

# Installation silencieuse de iptables-persistent
if ! dpkg -s iptables-persistent >/dev/null 2>&1; then
    echo "Installation de iptables-persistent..."
    sudo apt update
    # Note : Le paquet Debian pose des questions, c'est mieux de le faire manuellement
    # pour une installation sans surveillance, mais ici on le laisse tenter l'install standard.
    sudo apt install -y iptables-persistent
fi

sudo netfilter-persistent save

# ------------------------------------------------------------------
# Bloc 6 : Installation et configuration du serveur DHCP
# ------------------------------------------------------------------

echo "--- 6/9 : Installation du serveur DHCP (isc-dhcp-server) ---"

sudo apt install -y isc-dhcp-server

# ------------------------------------------------------------------
# Bloc 7 : Écriture du fichier de configuration DHCP
# ------------------------------------------------------------------

echo "--- 7/9 : Écriture de /etc/dhcp/dhcpd.conf ---"

# Déduire le réseau (ex: 192.168.10.1 -> 192.168.10.0)
NETWORK_ADDRESS=$(echo "$IP_LAN" | sed 's/\.[0-9]\+$/\.0/')

# Écriture du fichier de configuration DHCP
# On utilise le netmask le plus commun (/24)
sudo bash -c "cat > /etc/dhcp/dhcpd.conf <<EOF
# Configuration minimale pour un réseau local /24
subnet $NETWORK_ADDRESS netmask 255.255.255.0 {
  range $DHCP_START $DHCP_END;
  option routers $IP_LAN;
  option domain-name-servers $DNS_IP;
  default-lease-time 600;
  max-lease-time 7200;
}
EOF"

# ------------------------------------------------------------------
# Bloc 8 : Définir l'interface utilisée par le serveur DHCP
# ------------------------------------------------------------------

echo "--- 8/9 : Définition de l'interface DHCP ($IFACE_LAN) ---"

# Mise à jour de /etc/default/isc-dhcp-server
sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE_LAN\"/" /etc/default/isc-dhcp-server

# ------------------------------------------------------------------
# Bloc 9 : Redémarrage du service DHCP
# ------------------------------------------------------------------

echo "--- 9/9 : Redémarrage du service DHCP ---"

sudo systemctl restart isc-dhcp-server
sudo systemctl status isc-dhcp-server | grep Active

echo "=========================================================="
echo "✅ Configuration du routeur terminée."
echo "Adresse du routeur (LAN) : $IP_LAN"
echo "Serveur DHCP actif sur $IFACE_LAN."
echo "Vérifiez que le service isc-dhcp-server est bien 'active (running)'."
echo "=========================================================="
