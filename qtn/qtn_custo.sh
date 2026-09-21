#!/bin/sh
iwpriv wifi0 coc_mv_to_ndfs 0
echo "TI CUSTO"
tch_set_tos2ac_mapping.sh wifi0 0,1,1,2,2,3,3,3
echo "tn_custo.sh executed"