#!/bin/sh
# Copyright (c) 2014 Technicolor

INTERCEPT_SETUP="/usr/lib/intercept/setup.sh"
INTERCEPT_MARK="0x8000000/0x8000000"
INTERCEPT_PORT=8080

INTERCEPT_FW_PRECHAIN="intercept_pre"
INTERCEPT_FW_CHAIN="intercept_http"

intercept_active() {
    [ "$(uci_get_state intercept state active 0 )" == 1 ]
}

intercept_spoofip() {
    uci_get intercept dns spoofip
}

