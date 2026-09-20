#!/bin/sh
# Copyright (C) 2015 Technicolor Delivery Technologies, SAS

# Generate and return a case-sensitive, alphanumeric secret of specified length
__generate_secret() {
    local length="$1"
    # Exclude characters which may be confused with similar looking ones
    local exclude="0oOlI"
    local secret=$(cat /dev/urandom | tr -cd 'A-Za-z0-9' | tr -d "$exclude" | head -c $length)
    echo "$secret"
}

# Generate and return a 12-character secret that is used for CHAP authentication
generate_chap_secret() {
    echo $(__generate_secret 12)
}

# Generate and return a 20-character preshared key that is used for ipsec authentication
generate_ipsec_PSK() {
    echo $(__generate_secret 20)
}
