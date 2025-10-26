# `README.md` – Routeur Debian via USB : Robuste, Persistant et Pédagogique

## 🚀 Objectif du projet

Ce projet transforme un PC Debian en **routeur NAT sécurisé**, capable de partager une connexion Internet reçue via un smartphone (mode **USB tethering**) avec d'autres appareils connectés en **Ethernet**.

Le script est conçu pour être :
- **Robuste** : il nettoie les règles existantes avant toute configuration.
- **Persistant** : les réglages sont conservés après redémarrage.
- **Pédagogique** : chaque étape est commentée et structurée.

---

## 🧱 Architecture réseau

```
[Internet via USB smartphone] ←→ [PC Debian (routeur NAT + DHCP)] ←→ [PC secondaire via Ethernet]
```

| Élément              | Exemple                    | Rôle                          |
|----------------------|----------------------------|-------------------------------|
| Interface Internet   | `enx0ef9723bac04`          | Connexion vers le WAN         |
| Interface LAN        | `enp1s0`                   | Réseau local (clients)        |
| IP statique LAN      | `192.168.10.1`             | Adresse du routeur            |
| Plage DHCP           | `192.168.10.10 → .50`      | Attribution IP aux clients    |
| DNS utilisé          | `8.8.8.8`                  | Serveur DNS public            |

---

## 📜 Script principal : `config_routeur.sh`

Ce script configure le routeur en **9 étapes**, avec vérifications et nettoyage pour éviter les doublons ou conflits.

### Fonctionnalités clés :
- Saisie interactive des interfaces et IP
- Vérification de l’existence des interfaces réseau
- Attribution IP statique à l’interface LAN
- Activation du routage IP (`net.ipv4.ip_forward`)
- Nettoyage des règles `iptables` avant ajout
- Configuration du NAT (`MASQUERADE`) et des règles `FORWARD`
- Installation et configuration du serveur DHCP (`isc-dhcp-server`)
- Sauvegarde des règles avec `netfilter-persistent`
- Redémarrage du service DHCP

### Lancer le script :
```bash
chmod +x config_routeur.sh
sudo ./config_routeur.sh
```

---

## 📦 Dépendances

Le script installe automatiquement les paquets suivants si besoin :

- `iptables-persistent` : pour sauvegarder les règles NAT et les restaurer au démarrage
- `isc-dhcp-server` : pour attribuer des IP aux clients du réseau local

Installation manuelle possible :
```bash
sudo apt update
sudo apt install iptables-persistent isc-dhcp-server
```

---

## 💾 Fichiers modifiés pour la persistance

| Fichier                          | Rôle |
|----------------------------------|------|
| `/etc/sysctl.conf`              | Active le routage IP au démarrage |
| `/etc/iptables/rules.v4`        | Contient les règles NAT et FORWARD |
| `/etc/dhcp/dhcpd.conf`          | Définit la plage DHCP et le routeur |
| `/etc/default/isc-dhcp-server`  | Spécifie l’interface LAN pour le DHCP |

---

## ✅ Vérifications après installation

1. **Vérifier le service DHCP** :
   ```bash
   sudo systemctl status isc-dhcp-server
   # Doit afficher : Active (running)
   ```

2. **Vérifier l’interface LAN** :
   ```bash
   ip a show enp1s0
   # L’IP 192.168.10.1/24 doit être présente
   ```

3. **Tester depuis le PC client** :
   - Passerelle : `ping 192.168.10.1`
   - DNS : `ping 8.8.8.8`
   - Internet : `ping google.fr`

---

