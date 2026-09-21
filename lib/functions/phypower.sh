#!/bin/sh

phypower_intf()
{
  local intf="$1"
  local state="$2"
  local subport_suffix=""
  local subport2_suffix=""
  local phy_crossbar_resp=""

  if ([ "$intf" == "eth4" ] && (ethctl $intf media-type 2>&1 | grep -q 'eth4 has sub ports')); then
    subport_suffix="port 10"
    phy_crossbar_resp=$(ethctl $intf phy-crossbar 2>&1)
  fi

  # Work-around for CSP788570; make sure power-down works
  if [ "$state" = "down" ]; then
    local intf_media_type=$(ethctl $intf media-type $subport_suffix 2>&1)
    if ((echo ${intf_media_type} | grep -qi 'Auto-negotiation.* enabled') && (echo ${intf_media_type} | grep -qi 'Link is up')); then
        ethctl $intf media-type 100FD $subport_suffix  &> /dev/null
    fi
  fi

  ethctl $intf phy-power $state $subport_suffix &> /dev/null

  # sub ports need to be powered up explicitly
  if(echo $phy_crossbar_resp | grep -q "9"); then
    subport2_suffix="port 9"
    ethctl $intf phy-power $state $subport2_suffix &> /dev/null
  fi
}
