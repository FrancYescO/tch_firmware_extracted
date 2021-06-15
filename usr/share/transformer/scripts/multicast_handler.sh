#!/bin/sh

case "$1" in
  Reboot)
    /etc/init.d/multiap_controller restart
    /etc/init.d/multiap_agent restart ;;
  RTFD1)
    /usr/share/transformer/scripts/reset_agent_software_images.sh
    /usr/bin/map_reset_to_default.sh 1 ;;
  RTFD2)
    /usr/share/transformer/scripts/reset_agent_software_images.sh
    /usr/bin/map_reset_to_default.sh 2 ;;
esac

