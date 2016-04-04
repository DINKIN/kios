#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)";

echo "Compiling Kerberos.io for each board"

rm -rf $DIR/kios-*
rm -rf $DIR/.downloads/kerberosio-*
rm -rf $DIR/output/raspberrypi/build/kerberosio-*
rm -rf $DIR/output/raspberrypi2/build/kerberosio-*
rm -rf $DIR/output/raspberrypi3/build/kerberosio-*

$DIR/build.sh raspberrypi # should be all..
$DIR/build.sh raspberrypi mkrelease

echo "Creating Kerberos.io releases per board"

mkdir -p $DIR/releases
DATE=$(date +%Y%m%d)

echo "Preparing release for Raspberry Pi board"

mkdir -p $DIR/releases/rpi/$DATE
cp $DIR/kios-raspberrypi-* $DIR/releases/rpi/$DATE
for file in $DIR/output/raspberrypi/build/kerberosio-machinery*/kerberosio*; do cp -v -- "$file" "$DIR/releases/rpi/$DATE/machinery_${file##*/}"; done
cd $DIR/output/raspberrypi/target/var/www/web && tar czf $DIR/releases/rpi/$DATE/web.tar.gz .

echo "Preparing release for Raspberry Pi2 board"

mkdir -p $DIR/releases/rpi2/$DATE
cp $DIR/kios-raspberrypi2-* $DIR/releases/rpi2/$DATE
for file in $DIR/output/raspberrypi2/build/kerberosio-machinery*/kerberosio*; do cp -v -- "$file" "$DIR/releases/rpi2/$DATE/machinery_${file##*/}"; done
cd $DIR/output/raspberrypi2/target/var/www/web && tar czf $DIR/releases/rpi2/$DATE/web.tar.gz .

echo "Preparing release for Raspberry Pi3 board"

mkdir -p $DIR/releases/rpi3/$DATE
cp $DIR/kios-raspberrypi3-* $DIR/releases/rpi3/$DATE
for file in $DIR/output/raspberrypi3/build/kerberosio-machinery*/kerberosio*; do cp -v -- "$file" "$DIR/releases/rpi3/$DATE/machinery_${file##*/}"; done
cd $DIR/output/raspberrypi3/target/var/www/web && tar czf $DIR/releases/rpi3/$DATE/web.tar.gz .