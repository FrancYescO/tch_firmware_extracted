#!/bin/sh

# Copyright (c) 2017 Technicolor

INTERCEPT_SETUP="/usr/lib/intercept/setup.sh"
INTERCEPT_MARK="0x8000000/0x8000000"
INTERCEPT_PORT=8080

INTERCEPT_FW_PRECHAIN="intercept_pre"
INTERCEPT_FW_CHAIN="intercept_http"

IPSET_TABLE4="nointercept4"
IPSET_TABLE6="nointercept6"