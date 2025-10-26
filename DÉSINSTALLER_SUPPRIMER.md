# 🌐 Routeur NAT Debian - Scripts de gestion

Scripts Bash professionnels pour configurer et désactiver un routeur NAT sur Debian/Ubuntu.

## 📋 Description

Ce projet contient des scripts pour transformer une machine Debian en routeur NAT avec serveur DHCP, permettant de partager une connexion Internet entre plusieurs machines. Le script de désactivation permet d'annuler proprement toutes les modifications.

### Fonctionnalités

- ✅ Configuration complète du routage NAT (iptables)
- ✅ Serveur DHCP intégré
- ✅ Configuration d'IP statique sur interface LAN
- ✅ Activation/désactivation du forwarding IP
- ✅ Désinstallation propre des paquets
- ✅ Sauvegardes automatiques
- ✅ Validation des entrées utilisateur
- ✅ Gestion robuste des erreurs
- ✅ Interface colorée et intuitive

## 🔧 Prérequis

- **Système d'exploitation** : Debian 10+, Ubuntu 18.04+ ou dérivés
- **Privilèges** : Accès root (via `sudo`)
- **Interfaces réseau** : Au moins 2 interfaces (WAN et LAN)

### Paquets nécessaires (installés automatiquement)

- `iptables-persistent`
- `netfilter-persistent`
- `isc-dhcp-server`

## 📥 Installation

### 1. Cloner ou télécharger les scripts

```bash
# Télécharger le script de désactivation
wget https://example.com/disable_nat.sh

# Rendre le script exécutable
chmod +x disable_nat.sh
```

### 2. Vérifier les interfaces réseau

Identifiez vos interfaces réseau avant utilisation :

```bash
ip -br link show
```

Exemple de sortie :
```
lo               UNKNOWN        00:00:00:00:00:00
enp0s3           UP             08:00:27:xx:xx:xx  # Interface WAN (Internet)
enp0s8           UP             08:00:27:yy:yy:yy  # Interface LAN (réseau local)
```

## 🚀 Utilisation

### Script de désactivation

```bash
sudo ./disable_nat.sh
```

#### Menu interactif

Le script propose 6 options :

1. **Supprimer les règles NAT** - Nettoie uniquement iptables
2. **Arrêter le serveur DHCP** - Stoppe et désactive isc-dhcp-server
3. **Désactiver l'IP statique** - Supprime l'IP configurée sur l'interface LAN
4. **Désactiver le routage IP** - Désactive le forwarding IPv4
5. **TOUT DÉSACTIVER** - Exécute les options 1 à 4
6. **TOUT NETTOYER** - Désactive tout + désinstalle les paquets

### Exemples d'utilisation

#### Désactiver temporairement le NAT (garder les paquets)

```bash
sudo ./disable_nat.sh
# Choisir l'option 5
```

#### Désinstallation complète

```bash
sudo ./disable_nat.sh
# Choisir l'option 6
# Confirmer avec 'o'
```

#### Désactiver uniquement le DHCP

```bash
sudo ./disable_nat.sh
# Choisir l'option 2
```

## 📁 Structure du projet

```
.
├── disable_nat.sh          # Script de désactivation (ce fichier)
├── setup_nat.sh            # Script de configuration (à créer)
├── README.md               # Documentation
└── backups/                # Sauvegardes automatiques (créé par le script)
    └── sysctl.conf.bak-*
```

## 🔐 Sécurité

### Vérifications intégrées

- ✅ Validation des privilèges root
- ✅ Validation de l'existence des interfaces réseau
- ✅ Confirmation pour les actions destructives
- ✅ Sauvegardes automatiques des fichiers système
- ✅ Gestion des erreurs avec arrêt sécurisé

### Sauvegardes

Le script crée automatiquement des sauvegardes horodatées :

```
/etc/sysctl.conf.bak-20251026-143052
```

Pour restaurer une sauvegarde :

```bash
sudo cp /etc/sysctl.conf.bak-YYYYMMDD-HHMMSS /etc/sysctl.conf
```

## 🐛 Dépannage

### Erreur : "L'interface n'existe pas"

**Cause** : Interface réseau mal nommée ou inexistante

**Solution** :
```bash
# Lister les interfaces disponibles
ip -br link show

# Utiliser le nom exact affiché
```

### Erreur : "netfilter-persistent: command not found"

**Cause** : Paquet non installé (normal si désinstallé)

**Solution** : Le script gère ce cas automatiquement, aucune action nécessaire

### Le routage ne se désactive pas

**Solution** :
```bash
# Vérifier l'état du forwarding
sysctl net.ipv4.ip_forward

# Forcer la désactivation
sudo sysctl -w net.ipv4.ip_forward=0

# Redémarrer le système
sudo reboot
```

## 📝 Logs et vérification

### Vérifier l'état après désactivation

```bash
# Vérifier le forwarding IP
sysctl net.ipv4.ip_forward  # Doit afficher : 0

# Vérifier les règles iptables
sudo iptables -t nat -L -n -v

# Vérifier le statut DHCP
sudo systemctl status isc-dhcp-server
```

## 🤝 Contribution

Auteurs :
- **SMK** - Développeur principal
- **GitHub Copilot** - Assistance au développement
- **Google Gemini** - Revue et optimisation
- **Claude (Anthropic)** - Optimisation finale

## 📄 Licence

Ce projet est sous licence **MIT**.

```
MIT License

Copyright (c) 2025 smk & Copilot & Gemini & Claude

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🔗 Ressources utiles

- [Documentation Debian - Routage](https://wiki.debian.org/NetworkConfiguration)
- [Guide iptables](https://netfilter.org/documentation/)
- [Documentation isc-dhcp-server](https://www.isc.org/dhcp/)

## 📞 Support

Pour toute question ou problème :
- Ouvrir une issue sur le dépôt GitHub
- Consulter la section Dépannage ci-dessus
- Vérifier les logs système : `journalctl -xe`

---

**Note** : Ce script a été testé sur Debian 11/12 et Ubuntu 20.04/22.04. Testez toujours sur un environnement non-production avant déploiement.

**Version** : 1.0.0 | **Date** : 26 octobre 2025
