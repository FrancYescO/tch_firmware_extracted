#!/bin/sh

echo "RDPA lan init"

# XXX: Need to detect ports configuration
bs /bdmf/new port/index=lan0,cfg={emac=emac0}
bs /bdmf/new port/index=lan1,cfg={emac=emac1}
bs /bdmf/new port/index=lan2,cfg={emac=emac2}
bs /bdmf/new port/index=lan3,cfg={emac=emac3}
# bs /bdmf/new port/index=wlan0

# Create DS egress_tm objects
bs /bdmf/new egress_tm/dir=ds,index=0,level=queue,mode=sp port/index=lan0
bs /bdmf/new egress_tm/dir=ds,index=1,level=queue,mode=sp port/index=lan1
bs /bdmf/new egress_tm/dir=ds,index=2,level=queue,mode=sp port/index=lan2
bs /bdmf/new egress_tm/dir=ds,index=3,level=queue,mode=sp port/index=lan3

# Configure DS priority queues for LAN emac ports (emac ports schedulers have been already configured)
bs /bdmf/configure egress_tm/dir=ds,index=0 queue_cfg[0]={weight=0,drop_alg=dt,drop_threshold=128,red_high_threshold=0,red_low_threshold=0}
bs /bdmf/configure egress_tm/dir=ds,index=1 queue_cfg[0]={weight=0,drop_alg=dt,drop_threshold=128,red_high_threshold=0,red_low_threshold=0}
bs /bdmf/configure egress_tm/dir=ds,index=2 queue_cfg[0]={weight=0,drop_alg=dt,drop_threshold=128,red_high_threshold=0,red_low_threshold=0}
bs /bdmf/configure egress_tm/dir=ds,index=3 queue_cfg[0]={weight=0,drop_alg=dt,drop_threshold=128,red_high_threshold=0,red_low_threshold=0}


# Configure system bridge
# bs /bdmf/new bridge

echo "RDPA lan init end"
