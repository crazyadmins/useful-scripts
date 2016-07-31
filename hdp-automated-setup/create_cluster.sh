#!/bin/bash
#Author - Ratish Maruthiyodan
#Modified by - Kuldeep Kulkarni to add bootstrap function for installing required openstack client packages.
#Purpose - Script to Create Instance based on the parameters received from cluster.props file
##########################################################

bootstrap_mac()
{
	echo "Checking for required openstack client packages"
	ls -lrt $INSTALL_DIR/openstack >/dev/null 2>&1
	openstack_stat=$?
	ls -lrt $INSTALL_DIR/nova >/dev/null 2>&1
	nova_stat=$?
	ls -lrt $INSTALL_DIR/glance >/dev/null 2>&1
	glance_stat=$?
	ls -lrt $INSTALL_DIR/neutron >/dev/null 2>&1
	neutron_stat=$?

	if [ $openstack_stat -eq 0 ] && [ $nova_stat -eq 0 ] && [ $glance_stat -eq 0 ] && [ $neutron_stat -eq 0 ]
	then
		echo -e "Verified that required openstack client packages have been already installed!\nWe are good to go ahead :)"
	else
		echo -e "\nFound missing openstack client package(s)\nGoing ahead to install required client packages.. Enter Your Laptop's user password if prompted\n\n\nPress Enter to continue"
		read
		brew install python
		sudo pip install python-openstackclient
		sudo pip install python-novaclient
		sudo pip install python-neutronclient
	fi
}

find_image()
{
	
#	CENTOS_65="CentOS 6.5 (imported from old support cloud)"
	CENTOS_6="CentOS 6.6 (Final)"
	CENTOS_7="CentOS 7.0.1406"
#	UBUNTU_1204="Ubuntu 12.04"
#	UBUNTU_1404="Ubuntu 14.04"
#	SLES11SP3="SLES 11 SP3"

		
	req_os_distro=$(echo $OS | awk -F"[0-9]" '{print $1}'| xargs| tr '[:lower:]' '[:upper:]')
	req_os_ver=$(echo $OS | awk -F"[a-z]" '{$1="";print $0}'|awk -F '.' '{print $1$2}'| xargs| tr '[:lower:]' '[:upper:]')
	req_os_distro=$req_os_distro\_$req_os_ver
	eval req_os_distro=\$$req_os_distro
	if [ -z req_os_distro ]
	then
		echo -e "\nThe mentioned OS image is unavailable. The available images are:"
		glance image-list
		exit 1
	fi

	image_id=`glance image-list | grep "$req_os_distro" | cut -d "|" -f2,3 | xargs`
	echo $image_id

}

find_netid()
{
	echo $(neutron net-list | head -n 4 | tail -n1| cut -d"|" -f2 | xargs) 
}

find_flavor()
{
	nova flavor-list | grep -q "$FLAVOR_NAME"
	if [ $? -ne 0 ]
	then
		echo "Incorrect FLAVOR_NAME Set. The available flavors are:"
		nova flavor-list
		exit
	fi
	echo $FLAVOR_NAME

}


boot_clusternodes()
{
	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
	{
		set -e
		echo "Creating Instance:  [ $HOST ]"
        	nova boot --image $IMAGE_NAME  --key-name $KEYPAIR_NAME  --flavor $FLAVOR --nic net-id=$NET_ID $OS_USERNAME-$HOST > /dev/null
		set +e
	}
}

check_for_duplicates()
{
	echo -n "Checking for duplicate hostnames... "
	existing_nodes=`nova list | awk -F '|' '{print $3}' | xargs`

	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
        do
		echo $existing_nodes | grep -q -w $OS_USERNAME-$HOST
		if [ $? -eq 0 ]
		then
			echo -e "\n\nAn Instance with the name \"$HOST\" already exists. Please choose unique Hosnames"
			exit 1
		fi
	done
	echo "  [ OK ]"
		
}

spin()
{
	count=$(($1*2))

	spin[0]="-"
	spin[1]="\\"
	spin[2]="|"
	spin[3]="/"

	for (( j=0 ; j<$count ; j++ ))
	do
	  for i in "${spin[@]}"
	  do
        	echo -ne "\b$i"
	        sleep 0.12
  	  done
	done
}

check_vm_state()
{
	echo "Waiting for all the VMs to be started"
	STARTUP_STATE=0
	cat /dev/null > /tmp/opst-hosts
	STARTED_VMS=""
	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
	do
		while [ $STARTUP_STATE -ne 1 ]
        	do
			echo "$STARTED_VMS" | grep -w -q $HOST
			if [ "$?" -ne 0 ]
			then
				vm_info=`nova show $OS_USERNAME-$HOST | egrep "vm_state|PROVIDER_NET network"`
				#echo $HOST ":" $vm_info
				echo $vm_info | grep -i -q -w 'active'
				if [ "$?" -ne 0 ]
				then
					STARTUP_STATE=0
					echo -en "\nThe VM ($HOST) is still in State [`echo $vm_info | awk -F '|' '{print $3}'`]. Sleeping for 5s... "
					spin 5
					continue
				fi
			else
				STARTUP_STATE=1
				break
			fi
			IP=`echo $vm_info | awk -F'|' '{print $6}' | xargs`
			echo $IP  $HOST.$DOMAIN_NAME $HOST >> /tmp/opst-hosts
			STARTUP_STATE=1
			STARTED_VMS=$STARTED_VMS:$HOST
			echo "$HOST Ok"
		done
		STARTUP_STATE=0
	done
}

populate_hostsfile()
{
	sort /tmp/opst-hosts | uniq > /tmp/opst-hosts1
	echo -e "\nUpdating /etc/hosts file.. Enter Your Laptop's user password if prompted"
	mod=0

	## checking if local /etc/hosts file already have existing entries for nodenames being added
	while read entry
	do
		fqdn=$(echo $entry | awk '{print $2}')
		grep -w -q $fqdn /etc/hosts
		if [ "$?" -eq 0 ]
		then
			if [ "$mod" -ne 1 ]
			then
			  echo -e "\n'/etc/hosts' file on the laptop already contains entry for [ $fqdn ]. Replacing the entries and backing up existing file in /tmp/hosts"
			  cp -f /etc/hosts /tmp/hosts
			  mod=1
			fi
			sudo sed -i.bak "s/[0-9]*.*$fqdn.*/$entry/" /etc/hosts
		else
			sudo sh -c "echo $entry >> /etc/hosts"
		fi
	done < /tmp/opst-hosts1
	echo "Instances are created with the Following IPs:"	
	cat /tmp/opst-hosts1
#	sudo sh -c "cat /tmp/opst-hosts1 >> /etc/hosts"
}

## Start of Main

#set -x

if [ $# -ne 1 ] || [ ! -f $1 ];then
 echo "Insuffient or Incorrect Arguments"
 echo "Usage:: ./create_cluster.sh <cluster.props>"
 exit 1
fi

LOC=`pwd`
CLUSTER_PROPERTIES=$1
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null
INSTALL_DIR=/usr/local/bin
bootstrap_mac

echo -e "\nFinding the required Image"
IMAGE_NAME=$(find_image)
echo "Selected Image:" $IMAGE_NAME
IMAGE_NAME=`echo $IMAGE_NAME| cut -d '|' -f1 | xargs`

FLAVOR=`find_flavor`
NET_ID=$(find_netid)
echo "Selected Network: $NET_ID"
echo "Selected Flavor: $FLAVOR"

check_for_duplicates
echo -e "----------------------------------\n"
boot_clusternodes

check_vm_state
populate_hostsfile
echo -e "\n"
./setup_cluster.sh $CLUSTER_PROPERTIES