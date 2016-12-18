#!/bin/bash
#Script to sync repos

PVT_KEYFILE="/Users/kkulkarni/.ssh/id_rsa"
VERSION=$1
OS=$2

if [ $# -ne 2 ]
then
	echo -e "Usage: $0 AMBARI_VERSION OS_VERSION\ne.g. $0 2.4.2.0 centos7"
	exit
fi

echo "http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$VERSION/ambari.repo" > list_ambari

for server in new-openstack-hdp-repo-server-1.openstacklocal new-openstack-hdp-repo-server-2.openstacklocal
do
	scp -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" list_ambari  root@$server:/root/list_ambari

	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$server "sh reposync_hdp.sh list_ambari `echo $OS`"
done
