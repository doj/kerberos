#!/bin/sh

# setup environment variables for qt from homebrew
export PATH="/usr/local/opt/qt/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/qt/lib"
export CPPFLAGS="-I/usr/local/opt/qt/include"
export PKG_CONFIG_PATH="/usr/local/opt/qt/lib/pkgconfig:$PKG_CONFIG_PATH"

rm -rf kerberos.app kerberos.dmg
set -e
qmake
make
macdeployqt kerberos.app -dmg

echo
echo 'start the application with: $ open kerberos.app'
echo 'clean up the build directory with: $ make distclean'
