#!/bin/sh

TIM_mount(){
	PREFIX=/chroot
			for i in /dev /proc /sys /etc/config /tmp /etc/passwd /usr/bin/xdslctl /usr/lib/libxdslctl.so /usr/bin/seltctl /usr/lib/libseltctl.so
			do
							echo "[+] Mounting $i into ${PREFIX}"
							[ -d $i ] && mkdir -p ${PREFIX}/$i
							[ -f $i ] && { D=${PREFIX}/$(dirname $i) ; mkdir -p $D ; touch $D/$(basename $i) ; }
							mount -orbind $i ${PREFIX}/$i
			done
}

TIM_unmount(){
	PREFIX=/chroot
	for i in $(mount | grep ${PREFIX} | awk '{print $3}' | sort -r)
	do 
		echo "   - $i"
		umount $i
	done

}