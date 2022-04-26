# usbip
USB over IP cross plateform

Brouillon en attente de clarifier

# port USB distant (par Ethernet)

# Revient à brancher virtuellement un périphérique USB à distance

# Exemple : scanner depuis une machine (client) à distance de la machine à laquelle on a connecté le scanner en USB (serveur)
#           => le client aura localement le port USB du serveur alors qu'il n'est pas physiquement attaché au client

# Nota : test réalisé en virtu (KVM/Qemu) ; une VM (serveur ; Debian Bullseye) aura accès au scanner DCP-195C, une autre VM (client ; Debian Buster) aura accès à distance au port USB

# L'opération sera réussie si on peut scanner depuis le client avec Simple Scan et les pilotes



# serveur

# https://developer.ridgerun.com/wiki/index.php?title=How_to_setup_and_use_USB/IP
# https://www.linux-magazine.com/Issues/2018/208/Tutorial-USB-IP


root@vm-bullseye:~# lsusb | grep -i DCP-195C
Bus 003 Device 002: ID 04f9:0222 Brother Industries, Ltd DCP-195C
# => imprimante/scanner Brother DCP-195C détectée



# Nécessaire ? Supprimer packages problématiques
# KO ?   12  apt-get remove --purge usbip* libusbip*

# Nécessaire ?
root@impression:~# #apt# search linux-perf ; #apt# install linux-perf/stable
...
linux-perf/stable,now 5.10.106-1 i386
  outils d’analyse de performances pour Linux – métapaquet

linux-perf-5.10/stable,now 5.10.106-1 i386
  Performance analysis tools for Linux 5.10
...
root@impression:~# #apt# install linux-perf/stable


root@vm-bullseye:~# apt install usbip


# Extraire ID de bus
root@impression:~# usbip list -l | grep -i -B 2 DCP-195C
usbip: error: Protocol spec without prior Class and Subclass spec at line 23299
 - busid 3-1 (04f9:0222)
   Brother Industries, Ltd : DCP-195C (04f9:0222)
# => usbip voit déjà product:vendor à 04f9:0222 et busid à 1-1
# Nota 1 : pour l'erreur éventuelle non bloquante, voir dessous procédure de MAJ usb.ids
# Nota 2 : cette commande donne la liste des périphériques USB externes attachés physiquement à ce PC et ne correspond pas en totalité à la liste de la commande lsusb



# Démarrer les modules nécessaires
root@impression:~# modprobe usbip-core
root@impression:~# modprobe usbip-host
root@impression:~# lsmod | grep usbip
usbip_host             28672  0
usbip_core             24576  1 usbip_host
usbcore               208896  8 usbhid,usb_storage,usbip_host,ehci_hcd,uhci_hcd,usblp,uas,ehci_pci
usb_common             16384  4 ehci_hcd,uhci_hcd,usbcore,usbip_core



# Exporter un périphérique local (busid de la commande `usbip list -l`)
root@vm-bullseye:~# usbip bind -b 3-1
usbip: info: bind device on busid 3-1: complete



# Démarrer le serveur en mode debug (on voit tout ce qui se passe)
root@impression:~# usbipd --debug

# OU

# Démarrer le serveur en mode démon
root@impression:~# usbipd -D



# Vérifier que le serveur exporte les périphériques
root@impression:~# usbip list -r localhost
Exportable USB devices
======================
 - localhost
        3-1: Brother Industries, Ltd : DCP-195C (04f9:0222)
           : /sys/devices/pci0000:00/0000:00:1d.0/usb1/3-1
           : (Defined at Interface level) (00/00/00)



# Rendre permanents ...

TODO : rendre attach permanent et charger à chaque boot quand le réseau est opérationnel
très détaillé pour analyse : https://unix.stackexchange.com/questions/319267/systemd-how-to-make-a-systemd-service-start-after-network-fully-connected
service après réseau UP : https://unix.stackexchange.com/questions/319267/systemd-how-to-make-a-systemd-service-start-after-network-fully-connected
super tuto sur systemctl : https://linuxconfig.org/how-to-create-systemd-service-unit-in-linux


# ... les modules nécessaires
root@impression:~# cat /etc/modules  
...
# usbip server (remote USB devices by IP)
usbip-core
usbip-host


# ... au boot, les périphériques exportés et le chargement du démon
root@impression:~# crontab -e
...
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#@reboot /usr/sbin/usbip bind -b 3-1 ; usbipd -D
@reboot /data/config/export_local_usb_device.sh ; usbipd -D
# nota : ne pas oublier PATH car dans ce contexte, par défaut il n'y en a pas !

# Scripter l'export des périphériques USB et rendre exécutable
root@impression:~# cat << EOF > /data/config/export_local_usb_device.sh
#!/bin/bash

prod_vend=$( lsusb | grep -i DCP-195C | cut -d ' ' -f 6 )
l_port=$( usbip list -l | grep -E "busid.+$prod_vend" | cut -d ' ' -f 4 )
usbip bind -b $l_port
EOF
root@impression:~# chmod +x /data/config/export_local_usb_device.sh








# client

# https://www.linux-magazine.com/Issues/2018/208/Tutorial-USB-IP (client side)
# https://unix.stackexchange.com/questions/470827/usbip-error-open-vhci-driver


# voir aussi : plug_remote_usb.sh

root@lnj-buster:~# apt install usbip


root@lnj-buster:~# lsusb | grep -i DCP-195C


root@lnj-buster:~# usbip list -r impression.local
Exportable USB devices
======================
 - impression.local
        3-1: Brother Industries, Ltd : DCP-195C (04f9:0222)
           : /sys/devices/pci0000:00/0000:00:06.1/usb3/3-1
           : (Defined at Interface level) (00/00/00)
           :  0 - Printer / Printer / Bidirectional (07/01/02)
           :  1 - Vendor Specific Class / Vendor Specific Subclass / Vendor Specific Protocol (ff/ff/ff)
           :  2 - Mass Storage / SCSI / Bulk-Only (08/06/50)
# => usbip voit les mêmes product:vendor à 04f9:0222 et busid à 3-1



# Démarrer les modules nécessaires pour attacher les périphériques USB distants
root@lnj-buster:~# modprobe vhci-hcd
root@lnj-buster:~# lsmod | grep vhci
vhci_hcd               53248  0
usbip_core             32768  1 vhci_hcd
usbcore               294912  4 ehci_pci,ehci_hcd,uhci_hcd,vhci_hcd
usb_common             16384  3 usbip_core,usbcore,vhci_hcd
        
           

# Brancher (attacher) le périphérique USB distant selon ID USB
root@lnj-buster:~# usbip attach -r impression.local -b 3-1
# => si aucune erreur ne s'affiche, le périphérique distant est attaché !
# => il devient INdisponible pour d'autres machines


# On peut debbuger (ici il était déjà attaché)
root@goku:~# usbip --debug attach -r impression.local -b 3-1
usbip: debug: usbip.c:129:[run_command] running command: `attach'
usbip: debug: usbip_network.c:199:[usbip_net_recv_op_common] request failed at peer: 2
usbip: error: Attach Request for 3-1 failed - Device busy (exported)



# Vérifier que le périphérique USB distant est bien attaché localement
root@lnj-buster:~# lsusb | grep -i DCP-195C
Bus 005 Device 002: ID 04f9:0222 Brother Industries, Ltd DCP-195C



# Vérifier INdisponibilité du périphérique USB distant (logique, on ne peut pas brancher le même câble sur plusieurs hôtes !)
root@vm-bullseye-xfce:~# usbip list -r impression.local
usbip: info: no exportable devices found on impression.local
root@impression:~# usbip bind -b 3-1
usbip: error: device on busid 3-1 is already bound to usbip-host
# => INdisponible



# Vérifier depuis le serveur que le périphérique local n'est plus exportable
root@impression:~# usbip list -l | grep -i -B 2 DCP-195C
 - busid 3-1 (04f9:0222)
   Brother Industries, Ltd : DCP-195C (04f9:0222)
root@impression:~# usbip list -r localhost | grep -i -B 2 DCP-195C
usbip: info: no exportable devices found on localhost
root@impression:~# usbip bind -b 3-1
usbip: error: device on busid 3-1 is already bound to usbip-host



# Débrancher (détacher) le périphérique USB distant
root@vm-bullseye-xfce:~# usbip port
Imported USB devices
====================
Port 00: <Port in Use> at Full Speed(12Mbps)
       Brother Industries, Ltd : DCP-195C (04f9:0222)
       5-1 -> usbip://impression.local:3240/3-1
           -> remote bus/dev 001/002
# => connecté au port 00

root@vm-bullseye-xfce:~# usbip detach -p 00
usbip: info: Port 0 is now detached!

# Vérifier que le périphérique USB distant devient à nouveau exportable ...

# ... localement 
root@vm-bullseye-xfce:~# usbip list -r impression.local
Exportable USB devices
======================
 - impression.local
        1-1: Brother Industries, Ltd : DCP-195C (04f9:0222)
           : /sys/devices/pci0000:00/0000:00:1d.0/usb1/1-1
           : (Defined at Interface level) (00/00/00)
           :  0 - Printer / Printer / Bidirectional (07/01/02)
           :  1 - Vendor Specific Class / Vendor Specific Subclass / Vendor Specific Protocol (ff/ff/ff)
           :  2 - Mass Storage / SCSI / Bulk-Only (08/06/50)

# ... depuis le serveur
root@impression:~# usbip list -r localhost | grep -i -B 2 DCP-195C
======================
 - localhost
        1-1: Brother Industries, Ltd : DCP-195C (04f9:0222)














# Autres



# Faire changer l'icone représentant l'état de l'imprimante avec un cron (comme ça on sait si l'imprimante est disponible ou non)
# https://forum.xfce.org/viewtopic.php?id=12481
lnj@goku:~$ sed -i 's#^Icon.*#Icon=/data/noinstall/clock/clock_off.png#' .config/xfce4/panel/launcher-6/16508378171.desktop
lnj@goku:~$ sed -i 's#^Icon.*#Icon=/data/noinstall/Czkawka_GUI/wipe.png#' .config/xfce4/panel/launcher-6/16508378171.desktop
# nota : ici launcher-6 et 16508378171.desktop doivent être déterminés ...



# Scripter
root@vm-bullseye-xfce:~# SRV=impression.local
root@vm-bullseye-xfce:~# usbip list -r $SRV | grep -i DCP-195C | cut -d ':' -f 1 | tr -d ' '
3-1
root@vm-bullseye-xfce:~# usbip attach -r $SRV -b 3-1


# Analyse plus facile (quoi que ...)
root@impression:~# usbip list -p -l
busid=1-1#usbid=04f9:0222#
busid=5-1#usbid=04d9:1702#





Procédure de MAJ usb.ids
========================
Message "usbip: error: Protocol spec without prior Class and Subclass spec at line 23299"
=> peut être ignoré car non bloquant et n'est pas spécifiquement lié à usbip, mais aux périphériques USB

https://github.com/dorssel/usbipd-win/issues/163 indique que c'est lié à hwdata database (usb.ids)
root@impression:~# updatedb ; locate usb.ids
# => le fichier incriminé serait : /usr/share/misc/usb.ids

=> l'erreur à la ligne 23299 il y aurait une erreur de formatage dans le fichier usb.ids ; j'ai tenté de commenter la ligne et ai constaté que l'erreur ne s'affichait plus !

# Pour être plus propre j'ai remplacé la version bugguée par la dernière la dernière MAJ depuis http://www.linux-usb.org/usb-ids.html :
root@impression:~# wget http://www.linux-usb.org/usb.ids -O /usr/share/misc/usb.ids
# => plus d'erreur
