#!/bin/sh

get_client_auth_arguments() {
  local ssl_clientcert
  local ssl_clientkey
  local ssl_key_type
  local ssl_engine
  local ssl_key
  ssl_clientcert="$(uci get cwmpd.cwmpd_config.ssl_clientcert)"
  ssl_clientkey="$(uci get cwmpd.cwmpd_config.ssl_clientkey)"
  if [ -n "$ssl_clientcert" ] && [ -n "$ssl_clientkey" ]; then
     ssl_key_type="$(echo "$ssl_clientkey" | cut -f1 -d:)"
     ssl_engine="$(echo "$ssl_clientkey" | cut -f2 -d:)"
     ssl_key="$(echo "$ssl_clientkey" | cut -f3 -d:)"
     # In case that SPF is used the ssl_clientkey format will be: engine:<enginename>:<keyhandle>
     if  [ "$ssl_key_type" == "engine" ] && [ -n "$ssl_engine" ] && [ -n "$ssl_key" ]; then
        local key_handler="$(cat "$ssl_key")"
        # Using engine for client authentication.
        echo "--cert $ssl_clientcert --engine $ssl_engine --key-type ENG --key $key_handler"
     else
	# Using PEM file for client authentication
        echo "--cert $ssl_clientcert --key $ssl_clientkey"
     fi
  fi
}
