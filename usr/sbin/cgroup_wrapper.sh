#!/bin/ash

#set -x

# location to store PID
CGWRAP_PID="/cgroups/cpumemblk/minidlna_cgroup/tasks"

# check cgroup hierarchy is available, should be created by cg_mount script
if [ -d /cgroups/cpumemblk ];
then
  #check minidlna cgroup is available otherwise create dedicates cgroup
  if [ -d /cgroups/cpumemblk/minidlna_cgroup ];
  then
    echo "cgroup: minidlna cgroup already exist"
  else
    mkdir -p /cgroups/cpumemblk/minidlna_cgroup
    echo "cgroup: minidlna cgroup created"
  fi
  # call configuration script cgroup_limit_dlna(?)
  /usr/sbin/cgroup-limit-dlna.sh
  echo "cgroup: minidlna cgroup configured"
else
  echo "cgroup: NO cgroups hierarchy available!!! "

fi

#Search PID of the cgroup wrapper process
echo $$ > $CGWRAP_PID

echo -e "content of cgroup task list before\n"
cat $CGWRAP_PID

echo start process command="$@"
"$@"

echo -e "content of cgroup task list after\n"
cat $CGWRAP_PID

