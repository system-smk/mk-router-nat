#!/bin/bash
# Script de configuration du routeur NAT Debian (Version optimisée v2)
# Auteur : SMK & Copilot & Gemini & Claude
# Date : 2025-10-26
# Licence : MIT

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step() { echo -e "\n${BLUE}--- $1 ---${NC}"; }

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root (utilisez sudo)"
   exit 1
fi

# Fonction de validation d'adresse IP
validate_ip() {
    local ip="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $ip_regex ]]; then
        return 1
    fi
    
    # Vérifier que chaque octet est entre 0 et 255
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if ((octet < 0 || octet > 255)); then
            return 1
        fi
    done
    
    return 0
}

# Fonction de validation d'interface réseau
validate_interface() {
    local iface="$1"
    if [[ ! -d "/sys/class/net/$iface" ]]; then
        print_error "L'interface '$iface' n'existe pas"
        echo "Interfaces disponibles :"
        ip -br link show | awk '{print "  - " $1}'
        return 1
    fi
    return 0
}

# Fonction de calcul du réseau à partir d'une IP
calculate_network() {
    local ip="$1"
    echo "$ip" | cut -d. -f1-3
}

# Fonction de sauvegarde de fichier
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        print_info "Sauvegarde créée : $backup"
    fi
}

# Bannière de démarrage
echo "=========================================================="
echo "     🌐 Configuration du Routeur NAT Debian"
echo "=========================================================="
echo ""

# ------------------------------------------------------------------
# Bloc 1 : Choix des interfaces et des IPs
# ------------------------------------------------------------------

print_step "1/9 : Configuration des interfaces et adresses IP"

# Liste des interfaces disponibles
print_info "Interfaces réseau disponibles :"
ip -br link show | grep -v "lo" | awk '{printf "  - %-15s (%s)\n", $1, $2}'
echo ""

# Interface Internet
while true; do
    read -p "Interface connectée à Internet (ex: enx0ef9723bac04) : " IFACE_INTERNET
    if validate_interface "$IFACE_INTERNET"; then
        # Vérifier que l'interface a une adresse IP
        if ! ip -4 addr show dev "$IFACE_INTERNET" | grep -q "inet "; then
            print_warning "L'interface $IFACE_INTERNET n'a pas d'adresse IP !"
            print_info "Assurez-vous que votre connexion (USB tethering, etc.) est active"
            read -p "Continuer quand même ? (o/N) : " CONTINUE
            if [[ "$CONTINUE" == "o" || "$CONTINUE" == "O" ]]; then
                break
            fi
        else
            break
        fi
    fi
done

# Interface LAN
while true; do
    read -p "Interface LAN vers le second PC (ex: enp1s0) : " IFACE_LAN
    if [[ "$IFACE_LAN" == "$IFACE_INTERNET" ]]; then
        print_error "L'interface LAN doit être différente de l'interface Internet"
        continue
    fi
    if validate_interface "$IFACE_LAN"; then
        break
    fi
done

# IP statique LAN
while true; do
    read -p "Adresse IP statique pour l'interface LAN (ex: 192.168.10.1) : " IP_LAN
    if validate_ip "$IP_LAN"; then
        break
    else
        print_error "Format d'IP invalide. Utilisez le format xxx.xxx.xxx.xxx"
    fi
done

# Masque réseau
read -p "Masque réseau (défaut: 24 pour /24) : " NETMASK
NETMASK=${NETMASK:-24}

# Validation du masque
if [[ ! "$NETMASK" =~ ^[0-9]+$ ]] || ((NETMASK < 8 || NETMASK > 30)); then
    print_warning "Masque invalide, utilisation de /24 par défaut"
    NETMASK=24
fi

# Calcul automatique du réseau
NETWORK_BASE=$(calculate_network "$IP_LAN")

# Plage DHCP
while true; do
    read -p "Adresse de début de la plage DHCP (ex: ${NETWORK_BASE}.10) : " DHCP_START
    if validate_ip "$DHCP_START"; then
        break
    else
        print_error "Format d'IP invalide"
    fi
done

while true; do
    read -p "Adresse de fin de la plage DHCP (ex: ${NETWORK_BASE}.50) : " DHCP_END
    if validate_ip "$DHCP_END"; then
        break
    else
        print_error "Format d'IP invalide"
    fi
done

# Serveur DNS
while true; do
    read -p "Serveur DNS à utiliser (défaut: 8.8.8.8) : " DNS_IP
    DNS_IP=${DNS_IP:-8.8.8.8}
    if validate_ip "$DNS_IP"; then
        break
    else
        print_error "Format d'IP invalide"
    fi
done

# Choix du type de NAT (nouveau)
echo ""
print_info "=== Choix du type de NAT ==="
echo "1) SNAT (recommandé pour USB tethering et réseaux mobiles)"
echo "2) MASQUERADE (plus flexible, détecte automatiquement l'IP)"
echo ""
read -p "Votre choix (1 ou 2, défaut: 1) : " NAT_CHOICE
NAT_CHOICE=${NAT_CHOICE:-1}

# Résumé de la configuration
echo ""
print_info "=== Résumé de la configuration ==="
echo "  Interface Internet : $IFACE_INTERNET"
echo "  Interface LAN      : $IFACE_LAN"
echo "  IP du routeur      : $IP_LAN/$NETMASK"
echo "  Plage DHCP         : $DHCP_START - $DHCP_END"
echo "  Serveur DNS        : $DNS_IP"
if [[ "$NAT_CHOICE" == "1" ]]; then
    echo "  Type de NAT        : SNAT (IP fixe)"
else
    echo "  Type de NAT        : MASQUERADE (IP dynamique)"
fi
echo ""

read -p "Confirmer et continuer ? (o/N) : " CONFIRM
if [[ "$CONFIRM" != "o" && "$CONFIRM" != "O" ]]; then
    print_error "Configuration annulée"
    exit 0
fi

# ------------------------------------------------------------------
# Bloc 2 : Configuration de l'interface LAN
# ------------------------------------------------------------------

print_step "2/9 : Configuration de l'interface LAN ($IFACE_LAN)"

# Nettoyer l'interface avant configuration
ip addr flush dev "$IFACE_LAN" 2>/dev/null || true
ip addr add "$IP_LAN/$NETMASK" dev "$IFACE_LAN"
ip link set "$IFACE_LAN" up

print_success "Interface $IFACE_LAN configurée avec l'IP $IP_LAN/$NETMASK"

# ------------------------------------------------------------------
# Bloc 3 : Activation du routage IP (IP Forwarding)
# ------------------------------------------------------------------

print_step "3/9 : Activation du routage IP"

# Activation immédiate
sysctl -w net.ipv4.ip_forward=1 &>/dev/null

# Configuration persistante
backup_file /etc/sysctl.conf

if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    sed -i '/^#*net.ipv4.ip_forward/s/^#*//;s/=.*/=1/' /etc/sysctl.conf
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

print_success "Routage IP activé (immédiat et persistant)"

# ------------------------------------------------------------------
# Bloc 4 : Configuration du NAT avec iptables (CORRIGÉ)
# ------------------------------------------------------------------

print_step "4/9 : Configuration du NAT (iptables)"

print_info "Nettoyage des règles iptables existantes..."
iptables -t nat -F || true
iptables -F || true
iptables -X || true

# Détection de l'IP source sur l'interface Internet
IP_SOURCE=$(ip -4 addr show dev "$IFACE_INTERNET" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

if [[ "$NAT_CHOICE" == "1" ]]; then
    # Mode SNAT (recommandé pour tethering)
    if [[ -n "$IP_SOURCE" ]]; then
        print_info "Configuration NAT en mode SNAT avec IP source : $IP_SOURCE"
        iptables -t nat -A POSTROUTING -s "${NETWORK_BASE}.0/24" -o "$IFACE_INTERNET" -j SNAT --to-source "$IP_SOURCE"
        print_success "Règle SNAT configurée (IP fixe: $IP_SOURCE)"
    else
        print_warning "Impossible de détecter l'IP sur $IFACE_INTERNET"
        print_info "Basculement automatique en mode MASQUERADE"
        iptables -t nat -A POSTROUTING -o "$IFACE_INTERNET" -j MASQUERADE
        print_success "Règle MASQUERADE configurée (fallback)"
    fi
else
    # Mode MASQUERADE (dynamique)
    print_info "Configuration NAT en mode MASQUERADE (IP dynamique)"
    iptables -t nat -A POSTROUTING -o "$IFACE_INTERNET" -j MASQUERADE
    print_success "Règle MASQUERADE configurée"
fi

# Règles de FORWARD (communes aux deux modes)
iptables -A FORWARD -i "$IFACE_LAN" -o "$IFACE_INTERNET" -j ACCEPT
iptables -A FORWARD -i "$IFACE_INTERNET" -o "$IFACE_LAN" -m state --state RELATED,ESTABLISHED -j ACCEPT

print_success "Règles de routage (FORWARD) configurées"

# ------------------------------------------------------------------
# Bloc 5 : Sauvegarde des règles iptables
# ------------------------------------------------------------------

print_step "5/9 : Sauvegarde des règles iptables"

# Installation de iptables-persistent si nécessaire
if ! dpkg -s iptables-persistent &>/dev/null; then
    print_info "Installation de iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -qq
    apt install -y iptables-persistent
fi

# Sauvegarde des règles
netfilter-persistent save
print_success "Règles iptables sauvegardées (persistantes après redémarrage)"

# ------------------------------------------------------------------
# Bloc 6 : Installation et configuration du serveur DHCP
# ------------------------------------------------------------------

print_step "6/9 : Installation du serveur DHCP"

if ! dpkg -s isc-dhcp-server &>/dev/null; then
    print_info "Installation de isc-dhcp-server..."
    apt install -y isc-dhcp-server
    print_success "isc-dhcp-server installé"
else
    print_info "isc-dhcp-server est déjà installé"
fi

# ------------------------------------------------------------------
# Bloc 7 : Configuration DHCP
# ------------------------------------------------------------------

print_step "7/9 : Configuration de /etc/dhcp/dhcpd.conf"

backup_file /etc/dhcp/dhcpd.conf

# Calcul de l'adresse réseau et du masque
NETWORK_ADDRESS="${NETWORK_BASE}.0"
case $NETMASK in
    24) NETMASK_ADDR="255.255.255.0" ;;
    16) NETMASK_ADDR="255.255.0.0" ;;
    8)  NETMASK_ADDR="255.0.0.0" ;;
    *)  NETMASK_ADDR="255.255.255.0" ;; # Par défaut
esac

# Création du fichier de configuration DHCP
cat > /etc/dhcp/dhcpd.conf <<EOF
# Configuration générée automatiquement par routeur_nat.sh
# Date : $(date)

default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet $NETWORK_ADDRESS netmask $NETMASK_ADDR {
  range $DHCP_START $DHCP_END;
  option routers $IP_LAN;
  option domain-name-servers $DNS_IP;
  option broadcast-address ${NETWORK_BASE}.255;
}
EOF

print_success "Configuration DHCP créée"

# ------------------------------------------------------------------
# Bloc 8 : Définir l'interface utilisée par le serveur DHCP
# ------------------------------------------------------------------

print_step "8/9 : Configuration de l'interface DHCP"

backup_file /etc/default/isc-dhcp-server

# Configuration pour IPv4
if grep -q "^INTERFACESv4=" /etc/default/isc-dhcp-server; then
    sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE_LAN\"/" /etc/default/isc-dhcp-server
else
    echo "INTERFACESv4=\"$IFACE_LAN\"" >> /etc/default/isc-dhcp-server
fi

print_success "Interface DHCP configurée sur $IFACE_LAN"

# ------------------------------------------------------------------
# Bloc 9 : Redémarrage et vérification du service DHCP
# ------------------------------------------------------------------

print_step "9/9 : Démarrage du service DHCP"

systemctl restart isc-dhcp-server

# Attendre un peu que le service démarre
sleep 2

if systemctl is-active --quiet isc-dhcp-server; then
    print_success "Service DHCP démarré avec succès"
else
    print_error "Échec du démarrage du service DHCP"
    print_info "Vérifiez les logs avec : journalctl -xeu isc-dhcp-server"
    exit 1
fi

# Vérification de la connectivité Internet (optionnelle)
print_info "Test de connectivité Internet..."
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    print_success "Connectivité Internet OK"
else
    print_warning "Impossible de joindre Internet. Vérifiez votre connexion sur $IFACE_INTERNET"
fi

# ------------------------------------------------------------------
# Résumé final
# ------------------------------------------------------------------

echo ""
echo "=========================================================="
print_success "Configuration du routeur NAT terminée !"
echo "=========================================================="
echo ""
echo "📋 Informations importantes :"
echo "  • Adresse du routeur : $IP_LAN"
echo "  • Interface Internet : $IFACE_INTERNET"
if [[ -n "$IP_SOURCE" ]]; then
    echo "  • IP source (WAN)    : $IP_SOURCE"
fi
echo "  • Interface LAN      : $IFACE_LAN"
echo "  • Plage DHCP         : $DHCP_START - $DHCP_END"
echo "  • DNS                : $DNS_IP"
if [[ "$NAT_CHOICE" == "1" ]]; then
    echo "  • Type de NAT        : SNAT (IP fixe)"
else
    echo "  • Type de NAT        : MASQUERADE (dynamique)"
fi
echo ""
echo "🔧 Prochaines étapes :"
echo "  1. Connectez votre second PC à l'interface $IFACE_LAN"
echo "  2. Configurez-le en DHCP (automatique)"
echo "  3. Testez la connexion Internet depuis le second PC"
echo ""
echo "📊 Commandes utiles :"
echo "  • Vérifier le DHCP    : systemctl status isc-dhcp-server"
echo "  • Voir les baux DHCP  : cat /var/lib/dhcp/dhcpd.leases"
echo "  • Tester le routage   : iptables -t nat -L -n -v"
echo "  • Logs DHCP           : journalctl -u isc-dhcp-server -f"
echo ""
print_info "Pour désactiver ce routeur, utilisez le script de désactivation"
echo "=========================================================="
