#!/bin/sh

RIP_PATH="/proc/rip"
RIP_ID_EFU="0125"

EFU_RIP_PATH="$RIP_PATH/$RIP_ID_EFU"
EFU_TAG_LENGTH=264

find_program() {
  if ! which "$1" > /dev/null 2>&1 ; then
    echo "Error: program '$1' not found"
    exit 1
  fi
}

find_program base64
find_program dd
find_program md5sum

print_usage() {
  BIN=$(basename $0)
  echo ""
  echo "  usage: $BIN <tagfile>"
  echo ""
}

tag_is_valid() {
  base64 -d "$1" > /dev/null 2>&1 || return 1
  local numbytes=$(base64 -d "$1" | wc -c)
  [ "$numbytes" -eq $EFU_TAG_LENGTH ] || return 1
  TAGLENGTH=$numbytes
}

rip_create_entry() {
  [ -e "$RIP_PATH/new" ] || return 1
  echo $1 > "$RIP_PATH/new"
  [ -e "$RIP_PATH/$1" ] || return 1
}

rip_write_tag() {
  base64 -d "$1" > $EFU_RIP_PATH
}

rip_verify_tag() {
  local numbytes=$(cat "$EFU_RIP_PATH" | wc -c)
  [ "$numbytes" -eq $(($EFU_TAG_LENGTH + 1)) ] || return 1

  local tag_hash=$(base64 -d "$1" | md5sum | cut -f 1 -d ' ')
  local rip_hash=$(dd if="$EFU_RIP_PATH" bs=$EFU_TAG_LENGTH count=1 2>/dev/null | md5sum | cut -f 1 -d ' ')
  [ $tag_hash = $rip_hash ]
}

if [ $# -ne 1 ] ; then
  echo "Missing argument"
  print_usage
  exit 1
fi

TAGFILE=$1
if [ ! -e "$TAGFILE" ] ; then
  echo "File not found"
  print_usage
  exit 1
fi
if ! tag_is_valid "$TAGFILE" ; then
  echo "Invalid tag"
  print_usage
  exit
fi

if [ ! -e $EFU_RIP_PATH ] && ! rip_create_entry $RIP_ID_EFU ; then
  echo "Error: create EFU RIP entry failed"
  exit 1
fi

echo "Writing tag to RIP ($TAGLENGTH bytes).."
if ! rip_write_tag "$TAGFILE" ; then
  echo "Error: writing to RIP failed"
  exit 1
fi

echo "Verifying.."
if ! rip_verify_tag "$TAGFILE" ; then
  echo "Error: verification failed"
  exit 1
fi

echo "Success"

