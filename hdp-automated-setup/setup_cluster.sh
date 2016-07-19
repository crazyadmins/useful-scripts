#!/bin/bash
#Author - Kuldeep Kulkarni
#Script will setup and configure ambari-server/ambari-agents and hdp cluster
##########################################################

if [ $# -ne 1 ]
then
        echo -e "Usage $0 /path-to/cluster.props\nExample: $0 templates/multi-node/cluster.props"
        exit
fi

#Cleanup
rm -rf ~/.ssh/known_hosts

#Globals
LOC=`pwd`
CLUSTER_PROPERTIES=$1
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null
AMBARI_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME
AMBARI_AGENTS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2` 2>/dev/null
AMBARI_SERVER_IP=`grep -w $AMBARI_SERVER /etc/hosts|awk '{print $1}'`


generate_ambari_repo()
{
#This will generate internal repo file for Ambari Setup
echo "[Updates-ambari-$AMBARIVERSION]
name=ambari-$AMBARIVERSION - Updates
baseurl=http://172.26.64.249/ambari/$OS/Updates-ambari-$AMBARIVERSION/
gpgcheck=0
enabled=1
priority=1" > /tmp/ambari-$AMBARIVERSION.repo
}

prepare_hosts_file()
{
	echo -e "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" > /tmp/hosts
	for host in `grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`; do grep $host /etc/hosts >> /tmp/hosts;done
}	

bootstrap_hosts()
{
	
        for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		ssh -o "StrictHostKeyChecking no" root@$HOST rm -rf /etc/yum.repos.d/ambari-*.repo
                scp -o "StrictHostKeyChecking no" /tmp/ambari-"$AMBARIVERSION".repo root@$HOST:/etc/yum.repos.d/
                scp -o "StrictHostKeyChecking no" /tmp/hosts root@$HOST:/etc/hosts
		if [ "$OS" == "centos7" ]
		then
			echo $HOST
  	                ssh -o "StrictHostKeyChecking no" root@$HOST hostname "$HOST"
			ssh -o "StrictHostKeyChecking no" root@$HOST hostnamectl set-hostname "$HOST" --static
			ssh -o "StrictHostKeyChecking no" root@$HOST systemctl stop firewalld.service 2>/dev/null
			ssh -o "StrictHostKeyChecking no" root@$HOST systemctl disable firewalld.service
		elif [ "$OS" == "centos6" ]
		then
  	                ssh -o "StrictHostKeyChecking no" root@$HOST hostname "$HOST"
          	        ssh -o "StrictHostKeyChecking no" root@$HOST service iptables stop
                	ssh -o "StrictHostKeyChecking no" root@$HOST chkconfig iptables off
		fi
        done
}

setup_ambari_server()
{
	ssh -o "StrictHostKeyChecking no" root@$AMBARI_SERVER yum -y install ambari-server
	ssh -o "StrictHostKeyChecking no" root@$AMBARI_SERVER ambari-server setup -s
	ssh -o "StrictHostKeyChecking no" root@$AMBARI_SERVER ambari-server start
}

setup_ambari_agent()
{
	for host in `echo $AMBARI_AGENTS`
	do
		AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		ssh -o "StrictHostKeyChecking no" root@$AMBARI_AGENT yum -y install ambari-agent
		ssh -o "StrictHostKeyChecking no" root@$AMBARI_AGENT ambari-agent reset $AMBARI_SERVER 
		ssh -o "StrictHostKeyChecking no" root@$AMBARI_AGENT service ambari-agent start 
	done
}

setup_hdp()
{
	$LOC/generate_json.sh $CLUSTER_PROPERTIES $AMBARI_SERVER_IP
	echo -e "\n$(tput setaf 2)Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status!\n\nIt would not take more than 5 minutes :)\n\nHappy Hadooping!$(tput sgr 0)"
}


#Main starts here

generate_ambari_repo
prepare_hosts_file
bootstrap_hosts
setup_ambari_server
setup_ambari_agent
sleep 5
setup_hdp
