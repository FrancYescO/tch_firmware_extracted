#!/bin/sh

if test "$(ndconfig get DumaOS_Eula)" = "1" \
&& test "$(ndconfig get DumaOS_Setup_Done)" = "1"
then
	exit 0
else
	exit 1
fi
