#!/bin/sh

phypower_intf()
{
  local intf="$1"
  local state="$2"

  # Work-around for CSP788570; make sure power-down works
  if [ "$state" = "down" ]; then
    local intf_media_type=$(ethctl $intf media-type 2>&1)
    if ((echo ${intf_media_type} | grep 'Auto-negotiation enabled' >/dev/null) && (echo ${intf_media_type} | grep 'Link is up' >/dev/null)); then
        ethctl $intf media-type 100FD  &> /dev/null
    fi
  fi

  ethctl $intf phy-power $state  &> /dev/null
}

