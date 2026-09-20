#ifndef NETDUMA_AUTOADMIN_DEFINES_H
#define NETDUMA_AUTOADMIN_DEFINES_H

#define ND_CHAIN_PREFIX "nd_"
#define ND_EXCEPT_PREFIX "except_"
#define ND_CHAIN_NAME( name ) string.format( "%s%s", ND_CHAIN_PREFIX, name )
#define ND_EXCEPTION_CHAIN_NAME( name ) string.format( "%s%s", ND_EXCEPT_PREFIX, name )

#if defined( MODEL_R1 ) || defined( MODEL_R2 ) || defined( MODEL_DJA0231 ) || defined( MODEL_DJA0230 ) || defined(MODEL_DJA0230)
	#define USE_FW3_INCLUDE
	#define FW3_INCLUDE_SECTION "dumaos_fw_restart"
	#define FW3_INCLUDE_SCRIPT "/dumaos/apps/system/com.netdumasoftware.autoadmin/firewall_reloaded.sh"
#endif

#endif
