#!/bin/sh

fcctl | grep tcp-ack-mflows > /dev/null

if [ "$?" = 1 ]; then
  echo "tcp-ack-mflows not supported"
  bs /b/c egress_tm/dir=us,index=0  queue_cfg[0]={queue_id=0,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=1  queue_cfg[0]={queue_id=1,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=2  queue_cfg[0]={queue_id=2,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=3  queue_cfg[0]={queue_id=3,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=4  queue_cfg[0]={queue_id=4,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=5  queue_cfg[0]={queue_id=5,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=6  queue_cfg[0]={queue_id=6,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=7  queue_cfg[0]={queue_id=7,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}

  bs /b/c egress_tm/dir=us,index=20 queue_cfg[0]={queue_id=0,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=21 queue_cfg[0]={queue_id=1,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=22 queue_cfg[0]={queue_id=2,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=23 queue_cfg[0]={queue_id=3,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=24 queue_cfg[0]={queue_id=4,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=25 queue_cfg[0]={queue_id=5,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=26 queue_cfg[0]={queue_id=6,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
  bs /b/c egress_tm/dir=us,index=27 queue_cfg[0]={queue_id=7,drop_threshold=32,weight=0,drop_alg=dt,stat_enable=yes}
fi
