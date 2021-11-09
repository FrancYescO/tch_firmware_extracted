#!/bin/sh

OLD=${1:-$OLD_CONFIG}
MAIN_DIR=$OLD/usr/lib/lua
LED_DIR=$OLD/usr/lib/lua/ledframework

rm -rf $LED_DIR/

cp -r $MAIN_DIR /usr/lib/lua
