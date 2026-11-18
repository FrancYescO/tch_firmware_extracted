#!/bin/sh
dnsget -o timeout:5 -t naptr $1 | awk '{print $8}'| while read ptr_record; do
    dnsget -o timeout:5 -t srv $ptr_record | awk '{print $6}'| while read srv_record; do
        dnsget -o timeout:5 -t A $srv_record | awk '{print $3}' | while read address; do
            echo $address
        done
        dnsget -o timeout:5 -t AAAA $srv_record | awk '{print $3}' | while read address6; do
            echo $address6
        done
    done
done
