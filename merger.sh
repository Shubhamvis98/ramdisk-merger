
gethelp()
{
	echo "RAMDISK MERGER"
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

if ! command -v "magiskboot" >/dev/null 2>&1
then
	echo "[!]magiskboot is not in your PATH env"
	exit 1
fi

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
cd $ANDTMP; magiskboot unpack -h $ANDBOOT
mv ramdisk.cpio $BB/sbin/android.cpio

msg "Unpacking $TWRPBOOT"
cd $TWRPTMP; magiskboot unpack -h $TWRPBOOT

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
cd $ANDTMP; magiskboot repack $ANDBOOT
mv new-boot.img $WORKDIR/

msg "Boot image placed here: $WORKDIR/new-boot.img"

cleanup
