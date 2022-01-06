#!/bin/sh

ssl_key_conversion() {
  local ssl_clientkey
  local ssl_key_type
  local ssl_engine
  local ssl_key

  ssl_clientkey=$(uci get cwmpd.cwmpd_config.ssl_clientkey)
  if [ -n "$ssl_clientkey" ]; then
     ssl_key_type=$(echo "$ssl_clientkey" | cut -f1 -d:)
     ssl_engine=$(echo "$ssl_clientkey" | cut -f2 -d:)
     ssl_key=$(echo "$ssl_clientkey" | cut -f3 -d:)
     # In case that after upgrade SPFRSA is set as the engine name this needs to be changed to keystore
     if [ "$ssl_key_type" == "engine" ] && [ -n "$ssl_engine" ] && [ "$ssl_engine" == "SPFRSA" ] && [ -n "$ssl_key" ]; then
        uci set cwmpd.cwmpd_config.ssl_clientkey="engine:keystore:$ssl_key"
        uci commit
     fi
  fi
}
ssl_key_conversion
