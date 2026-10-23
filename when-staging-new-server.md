# When Staging a New Server

Checklist et procédures à exécuter lorsqu'un nouveau serveur/VM est provisionné.

## 1. Démarrer le serveur SSH

Si le port 22 est fermé, le service SSH n'est probablement pas installé ou démarré sur la VM.

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

### CentOS / RHEL / Fedora

```bash
sudo yum install -y openssh-server   # ou: sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
sudo systemctl status sshd
```

## 2. Ouvrir le firewall

### Ubuntu (UFW)

```bash
sudo ufw allow ssh
sudo ufw reload
```

### CentOS / RHEL (firewalld)

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

## 3. Vérifier depuis la machine locale

```bash
# Test ping
ping -c 2 192.168.56.6

# Test port 22
nc -z -w 3 192.168.56.6 22

# Test connexion SSH
ssh user@192.168.56.6
```

> Compte utilisé pour le staging : `user` / `user`

## 4. Diagnostic si le port 22 reste fermé

Depuis la console de la VM :

```bash
# Le service écoute-t-il ?
sudo ss -tlnp | grep :22

# Redémarrer le service
sudo systemctl restart ssh    # (sshd sur RHEL)

# Logs
sudo journalctl -u ssh -n 50  # (sshd sur RHEL)
```

Si `ss` n'affiche rien sur le port 22, le package `openssh-server` n'est pas installé — retourner à l'étape 1.

## 5. Configuration réseau VirtualBox : NAT (internet) + host-only (LAN staging)

Chaque VM doit avoir **2 cartes réseau** dans VirtualBox :

| Carte | Mode | Rôle | IP attendue |
|-------|------|------|-------------|
| Adapter 1 | NAT | Accès internet | `10.0.2.15` (DHCP VirtualBox) |
| Adapter 2 | Host-only (`vboxnet0`) | Accès depuis le Mac / LAN staging | `192.168.56.x` |

⚠️ **Piège connu :** si la carte NAT est ajoutée **après** l'installation (comme carte 1), l'invité Debian/Ubuntu **renomme** les interfaces : l'ancienne interface host-only passe de `enp0s8` à `enp0s9` et se retrouve **DOWN** (le netplan d'installation ne référençait que `enp0s8`). Résultat : le `192.168.56.x` disparaît alors que la carte VirtualBox semble bien configurée.

> 🚫 **Quelle IP utiliser depuis le Mac ?**
> La VM possède 2 IP mais **une seule est joignable depuis l'hôte** :
>
> | IP | Interface | Joignable depuis le Mac ? |
> |----|-----------|---------------------------|
> | `10.0.2.15` | NAT (virtuelle, interne à VirtualBox) | ❌ **Jamais** — le réseau NAT `10.0.2.x` vit à l'intérieur du moteur VirtualBox ; l'hôte n'en fait pas partie. La VM sort vers internet *via* ce NAT, mais personne ne peut entrer dessus par cette IP (hors règles `natpf` explicites). |
> | `192.168.56.x` | Host-only (`vboxnet0`, partagée Mac ↔ VMs) | ✅ **Oui** — c'est l'IP à utiliser pour SSH, les navigateurs, curl, les inventaires Ansible. |
>
> Donc depuis le Mac, toujours : `ssh user@192.168.56.x`, `http://192.168.56.x:<port>`. L'`ERR_ADDRESS_UNREACHABLE` dans le navigateur sur `10.0.2.x` est le symptôme normal de ce fonctionnement.

### Sur l'hôte (Mac) — VM éteinte obligatoire

```bash
VB=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
$VB controlvm <vm> acpipowerbutton          # arrêt propre
$VB modifyvm <vm> --nic1 nat --nictype1 82540EM --cableconnected1 on
$VB modifyvm <vm> --nic2 hostonlynetwork --hostonly-network2 vboxnet0 --cableconnected2 on   # (déjà présent en général)
$VB startvm <vm> --type headless
```

> `modifyvm` ne fonctionne que VM **éteinte** (erreur `VBOX_E_INVALID_OBJECT_STATE` sinon).

### Accès de secours après le renommage

La connexion directe sur `192.168.56.x` est morte au moment du diagnostic. Utiliser un port forwarding temporaire via le NAT pour reprendre la main :

```bash
$VB controlvm <vm> natpf1 "ssh-tmp,tcp,,2222,,22"
ssh -p 2222 user@127.0.0.1
# (passwd : user/user)
```

Si SSH refuse avec `REMOTE HOST IDENTIFICATION HAS CHANGED` (ancienne clé d'une autre VM sur le même port) :

```bash
ssh-keygen -R '[127.0.0.1]:2222'
```

### Dans la VM — corriger le netplan

Nouveau `/etc/netplan/00-installer-config.yaml` couvrant **les deux interfaces** :

```yaml
network:
  version: 2
  ethernets:
    enp0s8:            # NAT -> internet, IP 10.x via DHCP
      dhcp4: true
    enp0s9:            # host-only vboxnet0 -> IP fixe staging
      dhcp4: false
      addresses: [192.168.56.6/24]
```

> Adapter l'IP fixe et les noms d'interfaces à chaque VM (vérifier avec `ip -o link show` : les MAC permettent de savoir quelle carte est laquelle ; la MAC de la carte host-only est visible via `VBoxManage showvminfo <vm> --machinereadable | grep macaddress2`).

```bash
sudo cp /etc/netplan/00-installer-config.yaml{,.bak}
sudo netplan apply
```

### Vérification finale

```bash
ip -brief address          # enp0s8 UP 10.0.2.15 + enp0s9 UP 192.168.56.x
ip route                   # default via 10.0.2.2 dev enp0s8
ping -c 2 8.8.8.8          # internet OK
ping -c 2 google.com       # DNS OK
```

Puis depuis le Mac : `ping 192.168.56.x` et `ssh user@192.168.56.x` doivent fonctionner.

Supprimer la règle de port forwarding temporaire une fois terminé :

```bash
$VB controlvm <vm> natpf1 delete "ssh-tmp"
```

## 6. Clavier en français (AZERTY)

Le clavier par défaut des VM est `us` (QWERTY). Pour le passer en français :

```bash
# Console virtuelle (tty) + X11/Wayland
sudo localectl set-keymap fr          # keymap console
sudo localectl set-x11-keymap fr pc105   # layout graphique (modèle pc105)

# Vérification
localectl
# → VC Keymap: fr / X11 Layout: fr / X11 Model: pc105
```

Cela met à jour `/etc/default/keyboard` :

```
XKBMODEL="pc105"
XKBLAYOUT="fr"
BACKSPACE="guess"
```

### Vérification

```bash
sudo dumpkeys | head -1        # console : "fr"
sudo loadkeys fr               # recharger à la main si besoin
```

> ⚠️ **Important :** le layout configuré ici ne concerne que le **clavier de la VM** (console VirtualBox ou session graphique dans la fenêtre de la VM). Les sessions **SSH** ne sont pas affectées : le clavier utilisé dans un terminal distant est celui du **poste client** (le Mac). Les caractères tapés via SSH passent tels quels par le réseau — seul l'affichage/raccourcis de votre terminal local compte.

### Revenir en QWERTY (si nécessaire)

```bash
sudo localectl set-keymap us
sudo localectl set-x11-keymap us pc105
```

## 7. Prochaines étapes (staging)

Une fois le SSH accessible, provisionner le serveur avec les playbooks du repo :

- `kafka/` — installation Kafka
- `flink/` — installation Flink (JobManager, TaskManager, SQL Gateway)
- `polaris/` — installation Polaris + Polaris Console
- `sonarqube/` — installation SonarQube
- `airflow/` — installation Apache Airflow (scheduler + Web UI sur le port 8080)

Chaque dossier contient `install.sh`, `validate.sh`, `uninstall.sh` et un `inventory/hosts.yml` à renseigner avec l'IP du nouveau serveur.

````
This is the description of what the code block changes:
<changeDescription>
Ajoute airflow a la liste des playbooks de staging en section 7
</changeDescription>

This is the code block that represents the suggested code change:
```markdown
- `kafka/` — installation Kafka
- `flink/` — installation Flink (JobManager, TaskManager, SQL Gateway)
- `polaris/` — installation Polaris + Polaris Console
- `sonarqube/` — installation SonarQube
- `airflow/` — installation Apache Airflow (scheduler + Web UI sur le port 8080)

```

