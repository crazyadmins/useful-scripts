#!/bin/bash
#script will find latest available Ambari or HDP version from Hortonworks public repo and will sync it on local repo servers.
#################
#set -x

LOC="/root"

ts()
{
	echo "`date +%Y-%m-%d,%H:%M:%S`"
}

cleanup()
{
	echo "" > $LOC/output
}

get_latest_version()
{
	curl -s http://docs.hortonworks.com/index.html -o $LOC/output

	LATEST_HDP=`grep -B 2 Latest $LOC/output |grep href|grep 'HDP-'|grep -v Win|cut -d'>' -f2`
	LATEST_AMBARI=`grep -B 2 Latest $LOC/output |grep href|grep 'Ambari-'|cut -d'>' -f2`
	
	#Rough roundoff logic
	if [ `echo $LATEST_HDP|wc -c` == "6" ]
	then
		LATEST_HDP=`echo "$LATEST_HDP".0`
	fi

	if [ `echo $LATEST_AMBARI|wc -c` == "6" ]
	then
        	LATEST_AMBARI=`echo "$LATEST_AMBARI".0`
	fi
}

check_if_repo_already_synced()
{
	OS=$1

	if [ -d "/var/www/html/hdp/$OS/HDP-$LATEST_HDP" ]
	then
		echo "`ts`,No need to sync. HDP-$LATEST_HDP is already synced for $OS :)"
	else
		echo "`ts`,Could not find HDP-$LATEST_HDP for $OS on this repo server. Going ahead with sync"
		sync_repo hdp $OS
	fi

	if [ -d "/var/www/html/ambari/$OS/Updates-ambari-$LATEST_AMBARI" ]
	then
        	echo "`ts`,No need to sync. AMBARI-$LATEST_AMBARI is already synced for $OS :)"
	else
	        echo "`ts`,Could not find AMBARI-$LATEST_AMBARI for $OS on this repo server. Going ahead with sync"
	        sync_repo ambari $OS
	fi
}

sync_repo()
{
	TYPE=$1
	OS=$2

	if [ "$TYPE" == "ambari" ]
	then
		echo "http://public-repo-1.hortonworks.com/ambari/$OS/2.x/updates/$LATEST_AMBARI/ambari.repo" > $LOC/list_ambari_$OS
		echo "`ts`,All set! Syncing Ambari-$LATEST_AMBARI for $OS"
		sh $LOC/reposync_ambari.sh $LOC/list_ambari_$OS $OS
		echo "`ts`,Sync complete for Ambari-$LATEST_AMBARI for $OS!"
	elif [ "$TYPE" == "hdp" ]
	then
	        echo "http://public-repo-1.hortonworks.com/HDP/$OS/2.x/updates/$LATEST_HDP/hdp.repo" > $LOC/list_hdp_$OS
        	echo "`ts`,All set! Syncing HDP-$LATEST_HDP for $OS"
	        sh $LOC/reposync_hdp.sh $LOC/list_hdp_$OS $OS
        	echo "`ts`,Sync complete for HDP-$LATEST_HDP for $OS!"
	fi
}

#Main

cleanup
get_latest_version
check_if_repo_already_synced centos6 >> $LOC/autosync.log
check_if_repo_already_synced centos7 >> $LOC/autosync.log
