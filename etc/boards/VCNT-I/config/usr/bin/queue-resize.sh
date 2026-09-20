#!/bin/sh

logger -t wansensing "queue size changed"

for id in $(seq 0 7); do
	bs /b/c egress_tm/dir=us,index=$((id + 4))  queue_cfg[0]={queue_id=${id},drop_threshold=256,weight=0,drop_alg=dt,stat_enable=yes}
done
