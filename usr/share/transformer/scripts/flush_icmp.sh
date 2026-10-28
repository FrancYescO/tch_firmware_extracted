#!/bin/sh

# Before deleting the particular proto connections check for active flow entries.
if [ ! -z "$1" ] ; then
  flow_entries=`conntrack -L -p "$1" | wc -l`
  if [ ! -z "$flow_entries" ] && [ $flow_entries -gt 0 ]; then
    conntrack -D -p "$1"
  fi
fi
