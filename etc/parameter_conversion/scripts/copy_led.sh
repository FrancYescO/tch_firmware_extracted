#!/bin/sh

OLD=${1:-$OLD_CONFIG}
MAIN_DIR=$OLD/usr/lib/lua
LED_DIR=$OLD/usr/lib/lua/ledframework

mv $LED_DIR/ $OLD/usr/share/

cp -r $MAIN_DIR /usr/lib/lua

mv $OLD/usr/share/ledframework $MAIN_DIR
