{
  if ( $4 ~ /dnsmasq\[[0-9]+\]:/ ) {
	if ( $7 == "reply") {
	    cause=0
            if ( $10 == "NXDOMAIN" || $10 ~ /NODATA/ ) {
		cause="Lookup failure"
		SpecificProblem=$10
            }
            if ( $10 ~ /[0-9]+/ ) {
		cause="Lookup success"
		SpecificProblem=""
            }
            if ( cause != 0 ) {
                cmd="ubus send \"FaultMgmt.Event\" '{\"Source\":\"dnsmasq\", \"EventType\":\"DNS lookup\", \"ProbableCause\":\""cause "\", \"SpecificProblem\":\""SpecificProblem "\", \"AdditionalText\":\"name="$8",answer="$10"\"}'"
	        system(cmd)
	        system("cat /dev/null > "logfile" ")
	    }
	}
  }
  if ( $4 ~ /dnsmasq-dhcp\[[0-9]+\]:/ && ( $5 ~ /DHCPOFFER/ || $5 ~ /DHCPDECLINE/ )) {
	cause=0
        if ( $5 ~ /DHCPOFFER/ ) {
		cause="IP provisioning success"
		SpecificProblem=""
        }
	if ( $5 ~ /DHCPDECLINE/ ) {
		cause="DHCPDECLINE"
		SpecificProblem="Client reports the supplied address is already in use"
        }

	if ( cause != 0 ) {
            cmd="ubus send \"FaultMgmt.Event\" '{\"Source\":\"dnsmasq\", \"EventType\":\"DHCP server\", \"ProbableCause\":\""cause "\", \"SpecificProblem\":\""SpecificProblem "\", \"AdditionalText\":\"MacAddress="$7",IPAddress="$6"\"}'"
	    system(cmd)
	    system("cat /dev/null > "logfile" ")
	}
  }
}


END {

}
