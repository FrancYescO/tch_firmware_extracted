#!/bin/sh

#-- @depends cat
#-- @test which cat
case "`cat /dumaossystem/model`" in
  XR300|XR1000|XR1000V2|XRE1200)
    data_path=/tmp/media/nand/dumaos/rapp-data/
    main_path=/data/dumaos/rapp-data
    translations_path=/data/dumaos/language
    ;;
  LH1000)
    data_path=/dumaos/data/
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

odm="$(cat /dumaossystem/odm)"
if [ "${odm}" = "FOXCONN" ];then
	rm -rf ${main_path:?}/*
	rm -rf ${translations_path:?}/*
	sync
fi
