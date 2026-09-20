#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/usr/lib/hotspot/functions.sh


hotspot_log "control (action=\"$1\")"

case "${1:-default}" in
    boot)
        hotspot_init
    ;;
    start|reload)
        hotspot_checkwan
        hotspot_evaluate_state
    ;;
    stop)
        hotspot_state_set hotspotdaemon "down"
        hotspot_evaluate_state
    ;;
    # wireless radio state -> commitapply
    evaluate)
        hotspot_evaluate_state
    ;;
    # testing
    down)
        hotspot_state_set status "down"
        hotspot_apply_status
    ;;
    up)
        hotspot_state_set status "up"
        hotspot_apply_status
    ;;
    state)
        uci -P /var/state show hotspotd.state
    ;;
    *)
        hotspot_log "control error (invalid action)"
        exit 1
    ;;
esac

