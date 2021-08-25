#!/bin/sh

. $IPKG_INSTROOT/lib/functions.sh
. $IPKG_INSTROOT/lib/functions/network.sh
. $IPKG_INSTROOT/usr/lib/lot/functions.sh


lot_log "control (action=\"$1\")"

case "${1:-default}" in
    boot)
        lot_init
    ;;
    start|reload)
        lot_checkwan
        lot_evaluate_state
    ;;
    stop)
        lot_evaluate_state
    ;;
    # wireless radio state -> commitapply
    evaluate)
        lot_evaluate_state
    ;;
    state)
        uci -P /var/state show lot.state
    ;;
    *)
        lot_log "control error (invalid action)"
        exit 1
    ;;
esac

