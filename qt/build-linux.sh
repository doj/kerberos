#!/bin/sh

BIN=kerberos.linux
RELDIR=kerberos.release

if [ "$1" = clean ] ; then
    make distclean
    rm -rf "$RELDIR"
    exit 0
fi

rm -rf "$RELDIR"

set -e
qmake
make -j4

mkdir -p $RELDIR
mkdir -p $RELDIR/bin
mkdir -p $RELDIR/lib

cp $BIN $RELDIR/bin

LIBS=`ldd $BIN | grep -e Qt -e icu -e gcc -e stdc++ -e pthread -e png | awk '{print $3}'`
for LIB in $LIBS; do
    cp "$LIB" $RELDIR/lib/
done

SCRIPT=$RELDIR/kerberos.sh
echo '#/bin/sh' >> $SCRIPT
echo 'export LD_LIBRARY_PATH="'`pwd`/$RELDIR/lib'${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"' >> $SCRIPT
echo "bin/$BIN \"$@\"" >> $SCRIPT
chmod +x $SCRIPT
