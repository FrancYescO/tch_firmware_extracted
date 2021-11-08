#!/bin/sh
# Copyright (c) 2016 Technicolor
#common function to format and print named uci parameter output
	formatAndPrintNamedUciOutput ( ) {
		firstLine=$(head -n 1 "$2")
		if echo $firstLine | grep "ERROR";
		then
			echo -e " Unable to fetch Details\n" >> "$1"
			return
		fi
		cut -d @ -f 2- "$2" | sed 's/ \[.*\]//' > "$3"
		cp "$3" "$2"
		awk -F '.' '!seen[$1]++' "$2" | cut -d '.' -f 1 | while read line;
		do
			echo -e "\t$line\n" | tr 'a-z' 'A-Z' >> "$1"
			grep  "^$line\." "$2" | sed -e "s/^$line.//g" >> "$1"
			echo -e "\n--------------------------------------------------------------------------------\n\n" >> "$1"
		done
	}

#common function to format and print unnamed uci parameter output
	formatAndPrintUnnamedUciOutput ( ) {
		firstLine=$(head -n 1 "$2")
		if echo $firstLine | grep "ERROR";
		then
			echo -e " Unable to fetch Details\n" >> "$1"
			return
		fi
		cut -d . -f 3- "$2" | sed 's/ \[.*\]//' > "$3"
		cp "$3" "$2"
		awk -F '.' '!seen[$1]++' "$2" | cut -d '.' -f 1 | while read line;
		do
			echo -e "\t$line\n" | tr 'a-z' 'A-Z' >> "$1"
			grep -F "$line." "$2" | sed -e "s/^$line.//g" >> "$1"
			echo -e "\n--------------------------------------------------------------------------------\n\n" >> "$1"
		done
	}

collect_config_dump( ) {
	logLevel=`uci get mmpbx.voipdiagnostics.log_level`
	echo -e "=========================== SIP NETWORK DETAILS ===============================   \n" > "$1"
	maskedUri=\"+NUM\"
	TAB=$'\t'
	rootPath=`grep -F '^InternetGatewayDevice%.' /etc/config/transformer`
	if [ -n "$rootPath" ];
	then
		root="Device"
	else
		root="InternetGatewayDevice"
	fi

	TMPFILE=`mktemp -t diagnostics_dataXXXXXXX` && {
		for option in primary_registrar primary_registrar_port secondary_registrar secondary_registrar_port primary_proxy primary_proxy_port secondary_proxy secondary_proxy_port transport_type dtmf_relay;
		do
			echo "$(transformer-cli get uci.mmpbxrvsipnet.network.@sip_net.$option)" >> $TMPFILE
		done

		TMPFILE2=`mktemp -t diagnostics_dataXXXXXXX` && {
			cut -d @ -f 2- $TMPFILE | sed 's/\[.*\]//' > $TMPFILE2
			cut -d . -f 2- $TMPFILE2 >> "$1"
			if [[ ! -z "$logLevel" ]] && [[ "$logLevel" == "high" ]];
			then
				echo -e "======================= CODEC RELATED DETAILS ====================================    \n" >> "$1"

				echo "$(transformer-cli get uci.mmpbx.codec_filter.)" > $TMPFILE
				sed  -i '/media_filter/d' $TMPFILE
				sed -i 's/remove_silence_suppression  = 0/vad = 1/g' $TMPFILE
				sed -i 's/remove_silence_suppression  = 1/vad = 0/g' $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2

				echo -e "======================= TONE RELATED CONFIGURATIONS =============================     \n" >> "$1"

				echo "$(transformer-cli get uci.mmpbx.audionotification.)" > $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2
				echo "$(transformer-cli get uci.mmpbx.tone.)" > $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2

				echo -e "======================= SCC RELATED CONFIGURATIONS =============================     \n" >> "$1"

				echo "$(transformer-cli get uci.mmpbx.scc_entry.)" > $TMPFILE
				sed  -i '/service_base/d' $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2

				echo -e "======================= DIAL PLAN RELATED CONFIGURATIONS =============================   \n" >> "$1"

				echo "$(transformer-cli get uci.mmpbx.dial_plan_entry.)" > $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2

				echo "$(transformer-cli get uci.mmpbxbrcmfxsdev.device.)" > $TMPFILE
				formatAndPrintNamedUciOutput "$1" $TMPFILE $TMPFILE2

				echo -e "========================= SIGNALLING DETAILS =================================\n" >> "$1"

				echo "$(transformer-cli get uci.mmpbxbrcmcountry.global_provision.)" > $TMPFILE
				formatAndPrintUnnamedUciOutput "$1" $TMPFILE $TMPFILE2
			fi
		}
	}
	rm $TMPFILE $TMPFILE2
}
