#!/bin/sh

APP=kerberos.app

if [ "$1" = clean -o "$1" = distclean ] ; then
    make distclean
    rm -rf $APP kerberos.dmg
    exit 0
fi

# setup environment variables for qt from homebrew
export PATH="/usr/local/opt/qt/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/qt/lib"
export CPPFLAGS="-I/usr/local/opt/qt/include"
export PKG_CONFIG_PATH="/usr/local/opt/qt/lib/pkgconfig:$PKG_CONFIG_PATH"

rm -rf $APP kerberos.dmg
set -e
qmake
make -j4
macdeployqt $APP -dmg

echo
echo "start the application with: \$ open $APP"
echo 'clean up the build directory with: $ ./build-mac.sh distclean'

if [ "$1" = run ] ; then
    open $APP
fi
