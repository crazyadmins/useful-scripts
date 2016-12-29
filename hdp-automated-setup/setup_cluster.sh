#!/bin/bash
#Author - Kuldeep Kulkarni
#Contributor - Ratish Maruthiyodan
#Script will setup and configure ambari-server/ambari-agents and hdp cluster
##########################################################
if [ $# -ne 1 ]
then
        printf "Usage $0 /path-to/cluster.props\nExample: $0 templates/multi-node/cluster.props"
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
USERNAME=`cat /tmp/user`

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
                printf "\b$i"
                sleep 0.12
          done
        done
}

check_sshd_service() {
        loop=0
        echo $1
        nc -G 3 -w 2 $1 22
        while [ $? -eq 1 ]
        do
                printf "\nSSHD is not responding on $1. Sleeping for 10 seconds... "
                spin 10
                loop=$(( $loop + 1 ))
                if [ $loop -eq 10 ]
                then
                        printf "\nThere may be some error with the ssh connection or service startup on $1..."
                        read -p "Would you like to continue waiting for ssh to initialize ? [Y/N] : " choice
                        if [ "$choice" != "Y" ] && [ "$choice" != "y" ]
                        then
                                exit 1
                        fi
                fi

                nc -G 3 -w 2 $1 22 > /dev/null
        done
	printf "\n"
}

bootstrap_hosts()
{
	echo "Preparing /etc/hosts file, Setting hostname, Setting up Ambari Repo and disabling firewall on the Instances"
        for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		check_sshd_service $HOST
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST rm -rf /etc/yum.repos.d/ambari-*.repo 2> /dev/null
                scp -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/ambari-"$AMBARIVERSION".repo root@$HOST:/etc/yum.repos.d/ 2> /dev/null
                scp -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts root@$HOST:/etc/hosts 2> /dev/null
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST sed -i.bak "s/$USERNAME-$HOST/$HOST/g /etc/sysconfig/network"
		if [ "$OS" == "centos7" ]
		then
			echo $HOST
  	                ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST hostname "$HOST" 2> /dev/null
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST hostnamectl set-hostname "$HOST" && hostnamectl set-hostname "$HOST" --static 2> /dev/null
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST systemctl restart systemd-hostnamed
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST systemctl stop firewalld.service 2>/dev/null 2> /dev/null
			ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST systemctl disable firewalld.service 2> /dev/null
		elif [ "$OS" == "centos6" ]
		then
  	                ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST hostname "$HOST" 2> /dev/null
          	        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST service iptables stop 2> /dev/null
                	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$HOST chkconfig iptables off 2> /dev/null
		fi
        done
}

setup_ambari_server()
{
	printf "\n\t Installing Ambari-Server"

	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_SERVER yum -y install ambari-server
	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_SERVER ambari-server setup -s
	ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_SERVER ambari-server start
}

setup_ambari_agent()
{
	printf "\n\t Installing Ambari-Agents"

	for host in `echo $AMBARI_AGENTS`
	do
		AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_AGENT yum -y install ambari-agent
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_AGENT ambari-agent reset $AMBARI_SERVER           
		ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  root@$AMBARI_AGENT service ambari-agent start
	done
}

setup_hdp()
{
	$LOC/generate_json.sh $CLUSTER_PROPERTIES $AMBARI_SERVER_IP
	printf "\n$(tput setaf 2)Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status!\n\nIt would not take more than 5 minutes :)\n\nHappy Hadooping!\n$(tput sgr 0)"
	mv ~/.ssh/known_hosts.bak ~/.ssh/known_hosts
	end_time=`date +%s`
	start_time=`cat /tmp/start_time`
	runtime=`echo "($end_time-$start_time)/60"|bc -l`
	printf "\n\n$(tput setaf 2)Script runtime(Including time taken for manual intervention) - $runtime minutes!\n$(tput sgr 0)"
	TS=`date +%Y-%m-%d,%H:%M:%S`
	echo "$TS|`whoami`|`hostname -f`|$runtime" > /tmp/usage_track_"$USER"_"$TS"
}


#Main starts here

generate_ambari_repo
prepare_hosts_file
bootstrap_hosts
setup_ambari_server
setup_ambari_agent
sleep 5
setup_hdp
#upload usage tracker file to sftp
sftp -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" root@172.26.64.249 <<EOF
put /tmp/usage_track_"$USER"_"$TS" /root/
EOF
