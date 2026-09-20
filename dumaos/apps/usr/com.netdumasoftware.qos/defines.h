#ifndef QOS_DEFINES_H
	#define QOS_DEFINES_H

	#ifdef SDK_BROADCOM
		#define BRCM_BLOG
	#endif

	#ifdef VENDOR_TELSTRA
		#define USE_SUBSCRIBER_RATE
		#define USE_EXTRA_MARK

		#if defined(SDK_BROADCOM) && (defined(MODEL_LH1000) || defined(MODEL_DJA0231))
			#define USE_BRCM_HW
		#endif
	#endif

	#if defined(VENDOR_NETGEAR) && defined(MODEL_XR1000)
		#define USE_EXTRA_MARK
	#endif
	
	#ifdef USE_EXTRA_MARK
		#ifdef BRCM_BLOG
			#define USE_IPT_CLASSIFY
		#else
			#error "unsupported platform"
		#endif
	#endif
#endif
