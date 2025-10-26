# `README.md` – Routeur Debian via USB Tethering

## 🧭 Objectif

Ce projet transforme un PC Debian en **routeur NAT** pour partager une connexion Internet reçue via **USB tethering (smartphone)** avec un second PC connecté en **Ethernet**.

Il est conçu pour être **modulaire, pédagogique et portable**, avec configuration interactive et documentation claire.

---

## 🧱 Architecture réseau

```
[Internet via USB tethering] ←→ [PC Debian KDE] ←→ [PC secondaire via Ethernet]
```

- Interface Internet : USB (ex. `enx0ef9723bac04`)
- Interface LAN : Ethernet (ex. `enp1s0`)
- IP statique LAN : ex. `192.168.10.1`
- Plage DHCP : ex. `192.168.10.10 → 192.168.10.50`

---

## 📜 Script principal : `routeur_usb_ethernet.sh`

### Fonctionnalités :
- Configuration interactive (`read`) des interfaces et IP
- Attribution IP statique à l’interface LAN
- Activation du routage IP
- Configuration du NAT avec `iptables`
- Installation et configuration du serveur DHCP (`isc-dhcp-server`)
- Sauvegarde des règles avec `iptables-persistent`

### Lancer le script :
```bash
chmod +x routeur_usb_ethernet.sh
sudo ./routeur_usb_ethernet.sh
```

---

## 📁 Fichiers générés/modifiés

| Fichier                            | Rôle                                      |
|-----------------------------------|-------------------------------------------|
| `/etc/sysctl.conf`                | Activation du routage IP                  |
| `/etc/iptables/rules.v4`          | Sauvegarde des règles NAT                 |
| `/etc/dhcp/dhcpd.conf`            | Configuration du serveur DHCP             |
| `/etc/default/isc-dhcp-server`    | Définition de l’interface DHCP            |

---

## 🧪 Vérifications recommandées

- Interface LAN active avec IP statique :
  ```bash
  ip a show enp1s0
  ```
- Test depuis le second PC :
  ```bash
  ping 192.168.10.1
  ping 8.8.8.8
  ping google.fr
  ```

---

## 🧰 Dépendances

- `iptables`
- `iptables-persistent`
- `isc-dhcp-server`

Installer avec :
```bash
sudo apt update
sudo apt install iptables-persistent isc-dhcp-server
```

---

