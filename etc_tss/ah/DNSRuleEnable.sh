#!/bin/sh

[ "$newEnable" = "true" ] && cmclient SET "$obj".Status Enabled >/dev/null || cmclient SET "$obj".Status Disabled >/dev/null
