#!/bin/sh

#-- @depends cat
#-- @test which cat
case "`cat /dumaossystem/model`" in
  XR300|XR1000)
    data_path=/tmp/media/nand/dumaos/rapp-data/
    main_path=/data/dumaos/rapp-data
    ;;
  LH1000)
    data_path=/data/overlay/upper/dumaos/
    ;;    
  *)
    data_path=/dumaos/apps/
    ;;
esac

#-- @depends find
#-- @test which find
find "$data_path" -type "d" -name "data"  -exec find {} -type "f" \; | while read data_dir; do
	#-- @depends find
	#-- @test which find
	find "$data_dir" -type "f" | while read data_file; do
		#-- @depends rm
		#-- @test which rm
		rm -f "$data_file"
	done
done

if [ "$(cat /dumaossystem/model)" = "XR1000" ];then
	rm -rf $main_path/*
	sync
fi
