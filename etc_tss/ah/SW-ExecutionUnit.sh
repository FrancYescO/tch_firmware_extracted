#!/bin/sh
AH_NAME="SW-ExecutionUnit"

if [ -n "$newRequestedState" ]; then
	eeobj=`cmclient GETV ${obj}.ExecutionEnvRef`
	if [ -n "$eeobj" ]; then
		eename=`cmclient GETV ${eeobj}.Name`
		if [ "`cmclient GETV ${eeobj}.Enable`" = "false" ]; then
			# Attempt to change state of ExecutionUnit must fail if referred ExecEnv is disabled
			# Fault 9024
			echo "### ${AH_NAME}: Cannot change state of ${obj}: ExecEnv is disabled"
			exit 24
		fi
		if [ "$eename" = "OSGi" ]; then
			euid=`cmclient GETV ${obj}.EUID`
			if [ "$newRequestedState" = "Active" ]; then
				echo "### ${AH_NAME}: Starting unit ${euid}"
				osgicli start ${euid}
			elif [ "$newRequestedState" = "Idle" ]; then
				echo "### ${AH_NAME}: Stopping unit ${euid}"
				osgicli stop ${euid}
			fi
			if [ "$?" != 0 ]; then
				echo "### ${AH_NAME}: Got error $? from osgicli"
			fi
		elif [ "$eename" = "Docker" ]; then
			local dunit image_name cont_name host_ip host_obj
			# Get the deployment unit (image) connected to this container
			dunit=$(cmclient GETO "Device.SoftwareModules.DeploymentUnit.[ExecutionUnitList<${obj}]")
			image_name=$(cmclient GETV ${dunit}.Name)
			cont_name=$(cmclient GETV ${obj}.Name)

			# Each container has an associated Device.Hosts.Host object
			host_obj=$(cmclient GETV ${obj}.X_ADB_VirtualHostRef)

			if [ "$newRequestedState" = "Active" ]; then
				docker run  -d --name=${cont_name} ${image_name}
				if [ "$?" -eq "0" ]; then
					cmclient SETE ${obj}.Status Active

					# Update the address of the container in Hosts
					host_ip=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' ${cont_name})

					cmclient SET ${host_obj}.IPAddress ${host_ip}
					cmclient SET ${host_obj}.Active true
				else
					echo "### ${AH_NAME}: Got error $? from docker during creating container"
					exit 1
				fi
			elif [ "$newRequestedState" = "Idle" ]; then
				docker rm -f ${cont_name}
				cmclient SETE ${obj}.Status Idle

				cmclient SET ${host_obj}.Active false
			fi
		elif [ "$eename" = "LXC" ]; then
			cont_name=$(cmclient GETV ${obj}.Name)
			if [ "$newRequestedState" = "Active" ]; then
				lxc-start -n ${cont_name}
				[ "$?" -eq 0 ] && cmclient SETE ${obj}.Status Active
			elif [ "$newRequestedState" = "Idle" ]; then
				lxc-stop -n ${cont_name}
				[ "$?" -ne 1 ] && cmclient SETE ${obj}.Status Idle
			fi
		fi
	fi
fi
exit 0

