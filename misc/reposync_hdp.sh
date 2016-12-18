#!/bin/bash
#Author - Kuldeep Kulkarni
#Script to sync hdp/ambari repositories
########################################

OS=$2

if [ $# -ne 2 ]
then
	echo -e "Usage: $0 list_centos[0-9] OS_version\ne.g. $0 list_centos7 centos7"
	exit
fi

for BASE_URL in `cat $1`
do
	HDP_VERSION=`echo $BASE_URL|head -1|rev|cut -d'/' -f2|rev`
	echo "Creating repo for $BASE_URL"
	rm -rf /etc/yum.repos.d/hdp.repo
	cd /etc/yum.repos.d/ && wget $BASE_URL
	cd /var/www/html/hdp/$OS 
	reposync -r HDP-"$HDP_VERSION"
	createrepo /var/www/html/hdp/$OS/HDP-"$HDP_VERSION"
done
