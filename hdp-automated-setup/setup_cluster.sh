#!/bin/bash
#Author - Kuldeep Kulkarni
#Contributor - Ratish Maruthiyodan
#Script will setup and configure ambari-server/ambari-agents and hdp cluster
##########################################################

if [ $# -ne 1 ]
then
        echo -e "Usage $0 /path-to/cluster.props\nExample: $0 templates/multi-node/cluster.props"
        exit
fi

#Cleanup
cp ~/.ssh/known_hosts ~/.ssh/known_hosts.bak
echo "" > ~/.ssh/known_hosts


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
	echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" > /tmp/hosts
	for host in `grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`; do grep $host /etc/hosts >> /tmp/hosts;done
}	

check_sshd_service() {
        loop=0
        echo $1
        nc -w 2 $1 22 > /dev/null
        while [ $? -eq 1 ]
        do
                echo "SSHD is not responding on $1. Sleeping for 10 seconds..."
                sleep 10
                loop=$(( $loop + 1 ))
                if [ $loop -eq 10 ]
                then
                        echo -e "\nThere may be some error with the ssh connection or service startup on $1..."
                        read -p "Would you like to continue waiting for ssh to initialize ? [Y/N] : " choice
                        if [ "$choice" != "Y" ] && [ "$choice" != "y" ]
                        then
                                exit 1
                        fi
                fi

                nc -w 2 $1 22 > /dev/null
        done
}

bootstrap_hosts()
{
	
        for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		check_sshd_service $HOST
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST rm -rf /etc/yum.repos.d/ambari-*.repo
                scp -i $PVT_KEYFILE -o "StrictHostKeyChecking no" /tmp/ambari-"$AMBARIVERSION".repo root@$HOST:/etc/yum.repos.d/
                scp -i $PVT_KEYFILE -o "StrictHostKeyChecking no" /tmp/hosts root@$HOST:/etc/hosts
		if [ "$OS" == "centos7" ]
		then
			echo $HOST
  	                ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST hostname "$HOST"
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST hostnamectl set-hostname "$HOST" --static
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST systemctl stop firewalld.service 2>/dev/null
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST systemctl disable firewalld.service
		elif [ "$OS" == "centos6" ]
		then
  	                ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST hostname "$HOST"
          	        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST service iptables stop
                	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$HOST chkconfig iptables off
		fi
        done
}

setup_ambari_server()
{
	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_SERVER yum -y install ambari-server
	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_SERVER ambari-server setup -s
	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_SERVER ambari-server start
}

setup_ambari_agent()
{
	for host in `echo $AMBARI_AGENTS`
	do
		AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_AGENT yum -y install ambari-agent
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_AGENT ambari-agent reset $AMBARI_SERVER 
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" root@$AMBARI_AGENT service ambari-agent start 
	done
}

setup_hdp()
{
	$LOC/generate_json.sh $CLUSTER_PROPERTIES $AMBARI_SERVER_IP
	echo -e "\n$(tput setaf 2)Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status!\n\nIt would not take more than 5 minutes :)\n\nHappy Hadooping!$(tput sgr 0)"
	mv ~/.ssh/known_hosts.bak ~/.ssh/known_hosts 
}


#Main starts here

generate_ambari_repo
prepare_hosts_file
bootstrap_hosts
setup_ambari_server
setup_ambari_agent
sleep 5
setup_hdp
