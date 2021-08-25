#ifndef NETDUMA_ADBLOCKER_DEFINES_H
#define NETDUMA_ADBLOCKER_DEFINES_H

#define MIN_RESERVED_ID ( 1 )
#define MAX_RESERVED_ID ( 20 )
#define MAX_ENCODING_MEM_USE ( 1024 * 32 )
#define MAX_ENCODING_FILESIZE ( 1024 * 32 )

#if defined( MODEL_R1 ) || defined( MODEL_R2 ) || defined( MODEL_XR1000 ) || defined( MODEL_DJA0231 ) || defined( MODEL_DJA0230 ) || defined( MODEL_LH1000 )
	#define USE_CLOUD_SYNC
#else
	#define USE_FIRMWARE_LISTS
	#define FIRMWARE_LIST_PATTERN "/dumaos/apps/usr/com.netdumasoftware.adblocker/%d.DNn"
#endif

#ifdef MODEL_XR1000
	#define LIST_FILE_PATTERN "/data/dumaos/rapp-data/com.netdumasoftware.adblocker/data/usr/%d.DNn"
#else
	#define LIST_FILE_PATTERN "/dumaos/apps/usr/com.netdumasoftware.adblocker/data/usr/%d.DNn"
#endif

#ifdef USE_CLOUD_SYNC
	#ifdef MODEL_XR1000
		#define CLOUD_JSON_PATH "/data/dumaos/rapp-data/com.netdumasoftware.adblocker/data/usr/cloud_lists.json"
	#else
		#define CLOUD_JSON_PATH "/dumaos/apps/usr/com.netdumasoftware.adblocker/data/usr/cloud_lists.json"
	#endif
#endif

#endif
