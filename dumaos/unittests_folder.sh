#!/bin/sh
TMPDIR="/tmp/unittest"
if [ ! -d "$TMPDIR" ]
then
  printf "Creating tmp directory $TMPDIR"
  mkdir $TMPDIR
fi

UFNAME="newunittest"

DIR=$1
UDIR=$DIR/$UFNAME/

UF_EXISTS=false
if [ ! -d "$UDIR" ]
then
  printf "No folder named '$UFNAME' is in this location\n" >&2
  exit "1"
fi

if [ -z "$(ls -A $UDIR)" ]
then
  printf "Directory '$UDIR' is empty!" >&2
  exit "1"
fi

IS_RAPP=false
case "$UDIR" in
/dumaos/apps/*)
  IS_RAPP=true;;
esac



TMPPATHS="$TMPDIR/paths"

printf "$(cat << EOF
package.path = string.format("%%s;%%s",package.path,"/dumaos/api/?.lua;/dumaos/api/libs/?.lua;")
EOF
)\n\n" > $TMPPATHS

if [ "$IS_RAPP" = "true" ]
then
  printf "$(cat << EOF
package.path = string.format("%%s;%%s",package.path,"/dumaos/api/?.lua;/dumaos/api/libs/?.lua;")
package.path = string.format("%%s;%%s/?.lua",package.path,"$DIR")
package.cpath = string.format("%s;%s/?.so",package.cpath,"$DIR")
EOF
)\n\n" > $TMPPATHS
fi



for UNITPATH in $UDIR/*.lua; do
  FILE=$(basename $UNITPATH)
  printf "\n\n*******************************************************************************************************\nFOUND UNITTEST FILE: $FILE\n\n"

  TESTF="$UDIR/$FILE"
  OUTF="$TMPDIR/$FILE"

  printf "Compiling: $TESTF\n\n"
  luac -o $OUTF $TMPPATHS $TESTF

  printf "Running unit tests for $FILE...\n\n"
  lua $OUTF

  rm $OUTF
done

rm $TMPPATHS