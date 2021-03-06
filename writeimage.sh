#!/bin/bash -e


function usage() {
    echo "Usage: $0 [options...]" 1>&2
    echo ""
    echo "Available options:"
    echo "    <-i image_file> - indicates the path to the image file (e.g. -i /home/user/Download/image.img.gz)"
    echo "    <-d sdcard_dev> - indicates the path to the sdcard block device (e.g. -d /dev/mmcblk0)"
    echo "    [-n ssid:psk] - sets the wireless network name and key (e.g. -n mynet:mykey1234)"
    echo "    [-s ip/cidr:gw:dns] - sets a static IP configuration instead of DHCP (e.g. -s 192.168.1.101/24:192.168.1.1:8.8.8.8)"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

if [[ $(id -u) -ne 0 ]]; then echo "Please run as root"; exit 1; fi

function msg() {
    echo ":: $1"
}

while getopts "a:d:f:h:i:ln:o:p:s:w" o; do
    case "$o" in
        d)
            SDCARD_DEV=$OPTARG
            ;;
        i)
            DISK_IMG=$OPTARG
            ;;
        n)
            IFS=":" NETWORK=($OPTARG)
            SSID=${NETWORK[0]}
            PSK=${NETWORK[1]}
            ;;
        s)
            IFS=":" S_IP=($OPTARG)
            IP=${S_IP[0]}
            GW=${S_IP[1]}
            DNS=${S_IP[2]}
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$SDCARD_DEV" ] || [ -z "$DISK_IMG" ]; then
    usage
fi

function cleanup {
    set +e

    # unmount sdcard
    umount ${SDCARD_DEV}* >/dev/null 2>&1
}

trap cleanup EXIT

BOOT=$(dirname $0)/.boot
ROOT=$(dirname $0)/.root

if ! [ -f $DISK_IMG ]; then
    echo "could not find image file $DISK_IMG"
    exit 1
fi

if [[ $DISK_IMG == *.gz ]]; then
    msg "decompressing the gzipped image"
    gunzip -c $DISK_IMG > ${DISK_IMG::-3}
    DISK_IMG=${DISK_IMG::-3}
fi

umount ${SDCARD_DEV}* 2>/dev/null || true
msg "writing disk image to sdcard"
dd if=$DISK_IMG of=$SDCARD_DEV bs=1048576
sync

if which partprobe > /dev/null 2>&1; then
    msg "re-reading sdcard partition table"
    partprobe ${SDCARD_DEV}
fi

msg "mounting sdcard"
mkdir -p $BOOT
mkdir -p $ROOT

if [ `uname` == "Darwin" ]; then
    if ! [ -x /sbin/mount_fuse-ext2 ]; then
        echo "Missing mount_fuse-ext2 for EXT4 mounting! Further configuration stopped."
        echo ""
        echo "See http://osxdaily.com/2014/03/20/mount-ext-linux-file-system-mac/"
        echo "how to install ext4 mount support, please include 'Enabling EXT Write Support'."
        echo ""
        exit 1
    fi
    BOOT_DEV=${SDCARD_DEV}s1 # e.g. /dev/disk4s1
    ROOT_DEV=${SDCARD_DEV}s2 # e.g. /dev/disk4s2
    mount_msdos $BOOT_DEV $BOOT
    mount_fuse-ext2 $ROOT_DEV $ROOT    
else # assuming Linux
    BOOT_DEV=${SDCARD_DEV}p1 # e.g. /dev/mmcblk0p1
    ROOT_DEV=${SDCARD_DEV}p2 # e.g. /dev/mmcblk0p2
    if ! [ -e ${SDCARD_DEV}p1 ]; then
        BOOT_DEV=${SDCARD_DEV}1 # e.g. /dev/sdc1
        ROOT_DEV=${SDCARD_DEV}2 # e.g. /dev/sdc2
    fi
    mount $BOOT_DEV $BOOT
    mount $ROOT_DEV $ROOT
fi

# wifi
if [ -n "$SSID" ]; then
    msg "creating wireless configuration"
    conf=$ROOT/etc/wpa_supplicant.conf
    echo "update_config=1" > $conf
    echo "ctrl_interface=/var/run/wpa_supplicant" >> $conf
    echo "network={" >> $conf
    echo "    scan_ssid=1" >> $conf
    echo "    ssid=\"$SSID\"" >> $conf
    if [ -n "$PSK" ]; then
        echo "    psk=\"$PSK\"" >> $conf
    fi
    echo -e "}\n" >> $conf
fi

# static ip
if [ -n "$IP" ] && [ -n "$GW" ] && [ -n "$DNS" ]; then
    msg "setting static IP configuration"
    conf=$ROOT/etc/static_ip.conf
    echo "static_ip=\"$IP\"" > $conf
    echo "static_gw=\"$GW\"" >> $conf
    echo "static_dns=\"$DNS\"" >> $conf
fi

msg "unmounting sdcard"
sync
umount $BOOT
umount $ROOT
rmdir $BOOT
rmdir $ROOT

msg "you can now remove the sdcard"

