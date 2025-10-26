#!/bin/bash
# Script de désactivation du routeur NAT Debian (Version optimisée)
# Auteur : SMK & Copilot & Gemini & Claude
# Date : 2025-10-26
# Licence : MIT

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ️  $1${NC}"; }

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   print_error "Ce script doit être exécuté en root (utilisez sudo)"
   exit 1
fi

# Fonction de sauvegarde de fichier
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        print_info "Sauvegarde créée : $backup"
    fi
}

# Fonction de validation de l'interface réseau
validate_interface() {
    local iface="$1"
    if ! ip link show "$iface" &>/dev/null; then
        print_error "L'interface '$iface' n'existe pas"
        echo "Interfaces disponibles :"
        ip -br link show | awk '{print "  - " $1}'
        exit 1
    fi
}

# Affichage du menu
echo "=== Menu de désactivation du routeur NAT Debian ==="
print_warning "Ce script annule les changements effectués par le script de configuration."
echo ""
echo "Choisissez les actions à effectuer :"
echo "1) Supprimer les règles NAT (iptables)"
echo "2) Arrêter le serveur DHCP"
echo "3) Désactiver l'IP statique sur l'interface LAN"
echo "4) Désactiver le routage IP (net.ipv4.ip_forward)"
echo "5) TOUT DÉSACTIVER (1 à 4)"
echo "6) TOUT NETTOYER (Désactive tout + Désinstalle les paquets)"
echo ""

# Lecture et validation du choix
read -p "Votre choix (1-6) : " CHOIX
if [[ ! "$CHOIX" =~ ^[1-6]$ ]]; then
    print_error "Choix invalide. Veuillez entrer un nombre entre 1 et 6."
    exit 1
fi

# Demander l'interface LAN si nécessaire
IFACE_LAN=""
if [[ "$CHOIX" == "3" || "$CHOIX" == "5" || "$CHOIX" == "6" ]]; then
    echo ""
    read -p "Nom de l'interface LAN (ex: enp1s0) : " IFACE_LAN
    validate_interface "$IFACE_LAN"
fi

# Confirmation pour l'option 6
if [[ "$CHOIX" == "6" ]]; then
    echo ""
    print_warning "Vous avez choisi de TOUT NETTOYER : cela désactivera le routeur ET désinstallera les paquets."
    read -p "Confirmez-vous cette action irréversible ? (o/N) : " CONFIRM
    if [[ "$CONFIRM" != "o" && "$CONFIRM" != "O" ]]; then
        print_error "Action annulée."
        exit 0
    fi
fi

echo ""
echo "=== Début des opérations ==="
echo ""

# Action 1 : Suppression des règles NAT
if [[ "$CHOIX" == "1" || "$CHOIX" == "5" || "$CHOIX" == "6" ]]; then
    echo "--- Suppression des règles iptables ---"
    
    # Vérifier si des règles existent avant de les supprimer
    if iptables -t nat -L -n &>/dev/null; then
        iptables -t nat -F || true
        iptables -F || true
        iptables -X || true
        
        # Sauvegarder uniquement si netfilter-persistent est installé
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save
            print_success "Règles iptables supprimées et sauvegardées."
        else
            print_success "Règles iptables supprimées (netfilter-persistent non installé)."
        fi
    else
        print_info "Aucune règle iptables à supprimer."
    fi
    echo ""
fi

# Action 2 : Arrêt du serveur DHCP
if [[ "$CHOIX" == "2" || "$CHOIX" == "5" || "$CHOIX" == "6" ]]; then
    echo "--- Arrêt du serveur DHCP ---"
    
    if systemctl is-active --quiet isc-dhcp-server 2>/dev/null; then
        systemctl stop isc-dhcp-server
        systemctl disable isc-dhcp-server
        print_success "Serveur DHCP arrêté et désactivé."
    else
        print_info "Le serveur DHCP n'est pas actif ou n'est pas installé."
    fi
    echo ""
fi

# Action 3 : Désactivation de l'IP statique
if [[ "$CHOIX" == "3" || "$CHOIX" == "5" || "$CHOIX" == "6" ]]; then
    echo "--- Désactivation de l'IP statique sur $IFACE_LAN ---"
    
    if ip addr show dev "$IFACE_LAN" | grep -q "inet "; then
        ip addr flush dev "$IFACE_LAN"
        print_success "IP statique supprimée de $IFACE_LAN."
    else
        print_info "Aucune IP configurée sur $IFACE_LAN."
    fi
    echo ""
fi

# Action 4 : Désactivation du routage IP
if [[ "$CHOIX" == "4" || "$CHOIX" == "5" || "$CHOIX" == "6" ]]; then
    echo "--- Désactivation du routage IP ---"
    
    # Désactivation immédiate
    sysctl -w net.ipv4.ip_forward=0 &>/dev/null
    
    # Modification persistante du fichier sysctl.conf
    if [[ -f /etc/sysctl.conf ]]; then
        backup_file /etc/sysctl.conf
        
        # Supprimer les anciennes entrées et ajouter la nouvelle
        sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
        echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
        
        print_success "Routage IP désactivé (immédiat et persistant)."
    else
        print_warning "Fichier /etc/sysctl.conf introuvable. Désactivation temporaire uniquement."
    fi
    echo ""
fi

# Action 6 : Désinstallation des paquets
if [[ "$CHOIX" == "6" ]]; then
    echo "--- Désinstallation des paquets liés au routage ---"
    
    # Liste des paquets à désinstaller
    PACKAGES=("isc-dhcp-server" "iptables-persistent" "netfilter-persistent")
    PACKAGES_TO_REMOVE=()
    
    # Vérifier quels paquets sont installés
    for pkg in "${PACKAGES[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg"; then
            PACKAGES_TO_REMOVE+=("$pkg")
        fi
    done
    
    if [[ ${#PACKAGES_TO_REMOVE[@]} -gt 0 ]]; then
        apt purge -y "${PACKAGES_TO_REMOVE[@]}"
        apt autoremove -y
        print_success "Paquets désinstallés : ${PACKAGES_TO_REMOVE[*]}"
    else
        print_info "Aucun paquet à désinstaller."
    fi
    echo ""
fi

echo "=== Désactivation terminée ==="
print_info "Vous pouvez redémarrer les interfaces réseau avec : systemctl restart networking"
print_info "Ou redémarrer complètement le système avec : reboot"
