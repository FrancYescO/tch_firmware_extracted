#!/bin/sh

PPPDIR=/etc/ppp

mkdir $PPPDIR

OLD=${1:-$OLD_CONFIG}

cp $OLD/$PPPDIR/pppoesession_* $PPPDIR
