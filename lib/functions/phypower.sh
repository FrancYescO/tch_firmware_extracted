#!/bin/sh

phypower_intf()
{
  local intf="$1"
  local state="$2"
  local subport_suffix=""

  if ([ "$intf" == "eth4" ] && (ethctl $intf media-type 2>&1 | grep 'Interface eth4 has sub ports' >/dev/null)); then
      subport_suffix="port 10"
  fi

  # Work-around for CSP788570; make sure power-down works
  if [ "$state" = "down" ]; then
    local intf_media_type=$(ethctl $intf media-type $subport_suffix 2>&1)
    if ((echo ${intf_media_type} | grep -i 'Auto-negotiation enabled' >/dev/null) && (echo ${intf_media_type} | grep 'Link is up' >/dev/null)); then
        ethctl $intf media-type 100FD $subport_suffix  &> /dev/null
    fi
  fi

  ethctl $intf phy-power $state $subport_suffix &> /dev/null
}

