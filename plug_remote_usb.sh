#!/bin/bash

# Brancher ou débrancher à distance un périphérique USB (client local)

# Prérequis : usbip + module vhci-hcd chargé 
#  + pilotes et réglages locaux du périphérique distant
# Nota : dans le cas d'une imprimante, il faudra en plus cups

# TODO : dissocier la gestion usbip généraliste de celle ciblée de l'impression
# TODO : imprimante nommer friendly (par avec -p)

FN=$( basename ${BASH_SOURCE[0]} .sh ).sh

if [[ ! $( file /usr/sbin/usbip | grep ELF ) ]] ; then
	echo "Ce script nécessite usbip (http://usbip.sourceforge.net/) !"
	exit 1
fi

# TODO : vérifier vhci-hcd chargé, sinon tenter de l'activer => lsmod | grep vhci_hcd ; modprobe vhci-hcd

if [[ $1 == "" || $1 == "-h" || $1 == "--help" \
   || $3 == "" || $2 == "" || $4 != "" ]] ; then
	aide="Brancher ou débrancher à distance un périphérique USB."
	aide="$aide\n\nNota : nécessite les mêmes pilotes"
	aide="$aide et réglages locaux que sur l'hôte distant."
	aide="$aide\n\nSyntaxe :"
	aide="$aide\n $FN {on|off} HOTE_DISTANT PERIPH_DISTANT"
	aide="$aide\n\nOù PERIPH_DISTANT physiquement branché sur HOTE_DISTANT"
	aide="$aide\n et listé par \`usbip list -r HOTE_DISTANT\`"
	aide="$aide\n\nexemples :"
	aide="$aide\n $FN on impression.local DCP-195C"
	aide="$aide\n $FN off impression.local DCP-195C"
	echo -e "$aide"
	exit
fi

#SRV=impression.local
#MODEL=DCP-195C

STATE=$1
SRV=$2
MODEL=$3

R_DEVICE=${MODEL}_sur_$SRV

# Revenir en conditions initiales
lpadmin -x "$R_DEVICE" &> /dev/null

#PATH=$PATH:/usr/sbin
if [[ "$STATE" == "on" ]] ; then
	echo "on tente plug"
	if [[ $( usbip list -r $SRV 2>&1 | grep "no exportable" ) ]] ; then
		echo "$SRV NON disponible pour le moment !"
		exit 1
	fi
	r_port=$( \
		/usr/sbin/usbip list -r $SRV | grep -i $MODEL \
		| cut -d ':' -f 1 | tr -d ' ' \
	)
	if [[ -z "$r_port" ]] ; then
		echo "$MODEL NON disponible pour le moment !"
		exit 1
	fi
	/usr/sbin/usbip attach -r $SRV -b $r_port
	while [[ ! $( /usr/sbin/usbip port 2> /dev/null \
	 | grep -i $MODEL ) ]] ; do
		sleep 0.1
	done

#	lpadmin -p "Brother_DCP-195C" -E \
#		-v "usb://Brother/DCP-195C?serial=BROK3F453729" \
#		-P /data/cups/DCP195C.ppd

	uri=$( lpinfo -v | grep ^direct | grep -i $MODEL | cut -d ' ' -f 2 )
	# J'ai trouvé par hasard que les fichiers de /etc/cups/ppd
	# étaient identiques à cette localisation
	ppd_location=/usr/share/cups/model/$( \
		lpinfo --make-and-model "$MODEL" -m | grep -i $MODEL \
		| grep -v ^lsb | cut -d ' ' -f 1 \
	)
	lpadmin -p $R_DEVICE -E -v $uri -P $ppd_location
	echo "$R_DEVICE branché à distance !"
	exit 0
elif [[ "$STATE" == "off" ]] ; then
	echo "on tente unplug"
	if [[ ! $( /usr/sbin/usbip port | grep -i $MODEL ) ]] ; then
		echo "$MODEL NON branchée !"
		exit 1
	fi
	l_port=$( \
		/usr/sbin/usbip port | grep -i -B 1 $MODEL | grep ^Port \
		| cut -d ' ' -f 2 | tr -d ':'
	)
	/usr/sbin/usbip detach -p $l_port
	while [[ $( /usr/sbin/usbip port 2> /dev/null | grep -i $MODEL ) ]] ; do
		sleep 0.1
	done
	echo "$R_DEVICE débranché à distance !"
	exit 0
else
	echo "L'état $STATE n'existe pas !" ; exit
fi

echo fin a ne jamais atteindre
