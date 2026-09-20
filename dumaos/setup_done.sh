#!/bin/sh

if test "$(config get DumaOS_Eula)" = "1" \
&& test "$(config get DumaOS_Setup_Done)" = "1"
then
	exit 0
else
	exit 1
fi
