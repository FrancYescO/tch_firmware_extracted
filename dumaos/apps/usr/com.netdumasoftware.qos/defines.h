#ifndef QOS_DEFINES_H
	#define QOS_DEFINES_H

	#ifdef SDK_BROADCOM
		#define BRCM_BLOG
	#endif

	#ifdef VENDOR_TELSTRA
		#define USE_SUBSCRIBER_RATE
		#define USE_EXTRA_MARK
	#endif

	#if defined(SDK_BROADCOM) && (defined(MODEL_LH1000) || defined(ODM_TECHNICOLOR))
		#define USE_BRCM_HW
	#endif

	#if defined(MODEL_R1) || defined(VENDOR_TELSTRA) || defined(MODEL_XR1000)
		#define USE_IFB_BUILTIN
	#endif

	#if defined(VENDOR_NETGEAR) && defined(MODEL_XR1000)
		#define USE_EXTRA_MARK
	#endif

	#ifdef USE_EXTRA_MARK
		#ifdef BRCM_BLOG
			#if !defined(MODEL_DNA0332)
				#define USE_IPT_CLASSIFY
			#endif
		#else
			#error "unsupported platform"
		#endif
	#endif

#ifdef VENDOR_TELSTRA
#define USE_TOP_THROTTLE
#endif

#if defined( VENDOR_TELSTRA) || defined( VENDOR_NETDUMA ) || defined( VENDOR_NETGEAR )
#define USE_AUTO_WFH
#endif

#if defined(VENDOR_TELSTRA)
# define USE_AUTO_CLOUD_GAMING
#endif

#endif
