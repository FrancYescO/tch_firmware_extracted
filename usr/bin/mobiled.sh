#!/bin/sh

if [ -s /var/log/mobiled.log ]; then
	logger -t mobiled "Mobiled crashlog:"
	while IFS= read -r line; do
		logger -t mobiled "$line"
	done < /var/log/mobiled.log
	rm /var/log/mobiled.log
fi

exec "/usr/bin/mobiled" 2> /var/log/mobiled.log
