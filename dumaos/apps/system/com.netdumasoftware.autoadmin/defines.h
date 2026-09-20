#ifndef NETDUMA_AUTOADMIN_DEFINES_H
#define NETDUMA_AUTOADMIN_DEFINES_H

#define ND_CHAIN_PREFIX "nd_"
#define ND_EXCEPT_PREFIX "except_"
#define ND_CHAIN_NAME( name ) string.format( "%s%s", ND_CHAIN_PREFIX, name )
#define ND_EXCEPTION_CHAIN_NAME( name ) string.format( "%s%s", ND_EXCEPT_PREFIX, name )

#if defined(USE_FW3_INCLUDE)
	#define FW3_INCLUDE_SECTION "dumaos_fw_restart"
	#ifdef FW3_SPECIAL_PREFIX
		#define FW3_INCLUDE_SCRIPT "/dumaos/apps/system/com.netdumasoftware.autoadmin/firewall_reloaded.sh"
	#else
		#define FW3_INCLUDE_SCRIPT ND_SYSROOT("/dumaos/apps/system/com.netdumasoftware.autoadmin/firewall_reloaded.sh")
	#endif
#endif

#endif
