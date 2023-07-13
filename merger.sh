#!/bin/bash

set -e

banner()
{
clear
cat <<'EOF'
  '-,----------------------fossfrog's__
 /_/_  _ _   _/. _/_  /|,/_  _ _  _  _
/ \/_|/ / //_//_\/\  /  //_'/ /_//_'/ 
                              _/
git: shubhamvis98/ramdisk-merger

EOF
}

gethelp()
{
	banner
	echo "USAGE: $(basename $0) [OPTION] [FILE]"
	echo "	-h|--help #Help"
	echo "	-t|--twrp #Select TWRP image file"
	echo "	-a|--android #Select TWRP image file"
}

msg()
{
	echo
	echo "[+]$@"
}

chkarch()
{
	arch=$(uname -m)

	if [[ "$arch" == "arm"* ]]; then
	    MAGISKBOOT=`pwd`/bin/magiskboot_arm
	elif [[ "$arch" == "x86_64" ]]; then
	    MAGISKBOOT=`pwd`/bin/magiskboot_x86
	else
	    echo "[!]Unknown architecture"
	    exit
	fi
}

banner
chkarch

OPTARG=$(getopt -o :ha:t: -l help,android:,twrp: -- "$@")
if [ "$?" != "0" ]; then
  gethelp
  exit
fi

eval set -- $OPTARG

while true
do
	case "$1" in
		-h|--help)
			gethelp
			exit;;
		-a|--android)
			ANDBOOT="$2"
			shift 2;;
		-t|--twrp)
			TWRPBOOT="$2"
			shift 2;;
		*)
			break;;
	esac
done

if [ ! -e "$ANDBOOT" ] || [ ! -e "$TWRPBOOT" ]
then
	echo "[!]Invalid Input"
	exit 1
fi

WORKDIR=`pwd`
ANDTMP=$WORKDIR/andtmp
TWRPTMP=$WORKDIR/twrptmp
BB=$WORKDIR/_tmp

cleanup()
{
	rm -rf $BB/sbin/*.cpio $ANDTMP $TWRPTMP
	rm -rf $TWRPTMP $ANDTMP
}

msg "Removing old tmp files"
cleanup

echo -n "[?]Press return to edit device-specific details: "; read _null
nano $BB/sbin/device-params

mkdir $ANDTMP $TWRPTMP
cp $ANDBOOT $ANDTMP
cp $TWRPBOOT $TWRPTMP

msg "Unpacking $ANDBOOT"
cd $ANDTMP; $MAGISKBOOT unpack -h $ANDBOOT
mv ramdisk.cpio $BB/sbin/android.cpio

msg "Unpacking $TWRPBOOT"
cd $TWRPTMP; $MAGISKBOOT unpack -h $TWRPBOOT

ANDVER=`tail -n2 $ANDTMP/header | head -n1 | cut -d '=' -f2`
ANDLVL=`tail -n1 $ANDTMP/header | cut -d '=' -f2`
TWRPVER=`tail -n2 $TWRPTMP/header | head -n1 | cut -d '=' -f2`
TWRPLVL=`tail -n1 $TWRPTMP/header | cut -d '=' -f2`

rm header kernel* $TWRPBOOT

msg "Extracting ${TWRPBOOT}'s ramdisk"
cpio -i < ramdisk.cpio
rm ramdisk.cpio

msg "Patching ramdisk"
sed -i "s/$TWRPVER/$ANDVER/g;s/$TWRPLVL/$ANDLVL/g"  prop.default

msg "Compressing ramdisk"
find . | cpio -H newc -o > $BB/sbin/twrp.cpio
cd $BB; find . | cpio -H newc -o > $ANDTMP/ramdisk.cpio

msg "Repacking merged boot image"
cd $ANDTMP; $MAGISKBOOT repack $ANDBOOT
mv new-boot.img $WORKDIR/

msg "Boot image placed here: $WORKDIR/new-boot.img"

cleanup
