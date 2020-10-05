#!/bin/sh 

. /lib/functions.sh

# set -x

help() {
	cat <<EOF

--------------------------------------------------------------------------------------------------------
Usage :
	gpon_cli [help | -h] -c "COMMAND" [-a] ["ARGs"]

COMMAND and ARGs :
    omci unimode set -a { veip | v-uni | m-uni <unimum 1-4> | mix-vuni <uninum 2-5> | mix-veip <uninum 2-5> } 
                                                                                        : Set OMCI UNI Mode
    omci unimode get                                                                    : Get OMCI UNI Mode
--------------------------------------------------------------------------------------------------------

EOF
	
}

# ------------------omci uni mode set/get--------------- #
porttype="rg"

omci_port_type_get() {
	local uniidx=$1

	[ $uniidx -gt 3 ] && uniidx=3	
	while [ $uniidx -ge 0 ]; do 
		config_get porttype "uni_$uniidx" type
		if [ $porttype = "ont" ]; then
			return 0
		fi	
		uniidx=$(($uniidx - 1))
	done	

	return 0
}

omci_unimode_print(){
	local mode=$1
	local num=$2

	cat <<EOF
UNI Mode : $mode
UNI Num  : $num
EOF
	
}

# Command: omci unimode set
omci_unimode_set() {
	local mode=$1
	local uninum=$2	
	
	case "$mode" in 
		veip)
			uci set gpon.global.max=1
			uci set gpon.global.rgmode='veip'
			uci set gpon.uni_0.type=rg
			uci set gpon.uni_1.type=rg
			uci set gpon.uni_2.type=rg
			uci set gpon.uni_3.type=rg
			uci commit
		;;
		v-uni)
			uci set gpon.global.max=1
			uci set gpon.global.rgmode='vuni'
			uci set gpon.uni_0.type=rg
			uci set gpon.uni_1.type=rg
			uci set gpon.uni_2.type=rg
			uci set gpon.uni_3.type=rg
			uci commit
		;;
		mix-vuni)
			if [ -z $uninum ]; then
			       	echo "UNI num not specified"
				help 
				exit 1
			elif [ $uninum -lt 2 ] || [ $uninum -gt 5 ]; then
			       	echo "Invalid uni num : $uninum"
				help 
				exit 1
			fi	
			
			uci set gpon.global.max=$uninum
			uci set gpon.global.rgmode='vuni'
		
            uniidx=0
            while [ $uniidx -lt 4 ]; do 
                if [ $uniidx -lt $(($uninum - 1)) ]; then
				    uci set gpon.uni_$uniidx.type='ont'
                else
				    uci set gpon.uni_$uniidx.type='rg'
                fi                        
				uniidx=$(($uniidx + 1))	
            done                    
			uci commit
		;;
        mix-veip)
			if [ -z $uninum ]; then
			       	echo "UNI num not specified"
				help 
				exit 1
			elif [ $uninum -lt 2 ] || [ $uninum -gt 5 ]; then
			       	echo "Invalid uni num : $uninum"
				help 
				exit 1
			fi	
			
			uci set gpon.global.max=$(($uninum - 1))
			uci set gpon.global.rgmode='veip'

            uniidx=0
            while [ $uniidx -lt 4 ]; do 
                if [ $uniidx -lt $(($uninum - 1)) ]; then
				    uci set gpon.uni_$uniidx.type='ont'
                else
				    uci set gpon.uni_$uniidx.type='rg'
                fi                        
				uniidx=$(($uniidx + 1))	
            done                    
            uci commit
		;;
		m-uni)
			if [ -z $uninum ]; then
			       	echo "UNI num not specified"
				help 
				exit 1
			elif [ $uninum -lt 1 ] || [ $uninum -gt 4 ]; then
			       	echo "Invalid uni num : $uninum"
				help 
				exit 1
			fi	
			
			uci set gpon.global.max=$uninum
			uci set gpon.global.rgmode='none'

            uniidx=0
            while [ $uniidx -lt 4 ]; do 
                if [ $uniidx -lt $uninum ]; then
				    uci set gpon.uni_$uniidx.type='ont'
                else
				    uci set gpon.uni_$uniidx.type='rg'
                fi                        
				uniidx=$(($uniidx + 1))	
            done                 
			uci commit
		;;	
		"")
			echo "UNI mode not specified"
			help
			exit 1
		;;	
		*)
			echo "Invalid uni mode : $mode"
			help
			exit 1
		;;	
	esac
	echo "Info: Please reboot to reload this configuration."	
}

# Command: omci unimode get
omci_unimode_get() {
	local rgmode
	local portmax

	config_load gpon

	config_get rgmode "global" rgmode
	config_get max "global" max
	omci_port_type_get $max	

	case "$rgmode" in
		none)
			mode="m-uni"
		;;
		vuni)
			case "$porttype" in
				ont)
					mode="mix-vuni"
				;;
				rg)
					mode="v-uni"
				;;
			esac			
		;;
		veip)
			case "$porttype" in
				ont)
					mode="mix-veip"
                    max=$(($max + 1))
				;;
				rg)
					mode="veip"
				;;
			esac			
		;;

		*)
			mode="unknown"
		;;	
	esac

	omci_unimode_print $mode $max	
}

# ------------------omci uni mode set/get--------------- #
