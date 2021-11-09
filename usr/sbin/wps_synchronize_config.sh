#!/bin/sh

ubus call wireless.endpoint.profile enrollee_pbc "{'name' : 'ep0', 'event' : 'start'}"
