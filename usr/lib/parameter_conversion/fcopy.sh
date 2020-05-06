#!/bin/sh

do_copy() {
	local src=$1
	local dst=$2

	if [ -z $dst ]; then
		dst=$src
	fi

	local real_src=$old_config/${src#/}
	local real_dst=$new_config/${dst#/}

	if [ -d $real_src ]; then
		echo_debug "mkdir $real_dst"
		mkdir -p $real_dst
	elif [ -e $real_src ]; then
		echo_debug "copy $real_src to $real_dst"
		cp $real_src $real_dst
	elif [ -L $real_src ]; then
		link=$(readlink $real_src)
		if [ -z $(echo $link | sed "s/(overlay-whiteout)//") ]; then
			echo_debug "removing $real_dst ($real_src is whiteout)"
			rm -rf $real_dst
		else
			echo_debug "copy link $real_src $real_dst"
			cp -P $real_src $real_dst
		fi
	fi
}

do_copy_dir() {
	local src=${1%/}
	local dst=${2%/}
	
	local base
	local new
	
	for f in $(find $old_config/${src#/}); do
		base=${f#$old_config}
		if [ -z $dst ]; then
			new=$base
		else
			new=$dst/${base#$src}
		fi
		do_copy $base $new
	done
}

do_copy_file() {
	local src=$1
	local dst=$2
	local rename=$3
	
	if [ -z $dst ]; then
		# no renaming
		dst=$src
	elif [ -z $rename ]; then
		# rename of dir only
		dst=$dst/$(basename $src)
	else
		# rename of dir and file
		dst=$dst/$rename
	fi
	mkdir -p $(dirname $dst)
	do_copy $src $dst
}

copy() {
	src=$1
	dst=$2
	rename=$3

	local real_src=$old_config/${src#/}

	if [ -d $real_src ]; then
		do_copy_dir $src $dst
	elif [ -e $real_src -o -L $real_src ]; then
		do_copy_file $src $dst $rename
	else
		echo_debug "cannot copy [$old_config]$src: does not exist"
	fi
}
