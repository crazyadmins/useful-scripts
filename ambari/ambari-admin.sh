#!/bin/bash
#Author - Kuldeep Kulkarni ( http://crazyadmins.com )
#Note - Please do not use this script..work is still in progress! :)
####################################################

#Globals

LOC=`pwd`
PROP=kerberos.props
source $LOC/$PROP

usage()
{
	echo -e "$(tput setaf 2)USAGE:
	\n$(tput setaf 2)To Start/Stop all the services:$(tput sgr 0) $0 [startall|stopall]
	\n$(tput setaf 2)Get list of installed services:$(tput sgr 0) $0 listall
	\n$(tput setaf 2)Start/Stop individual service:$(tput sgr 0) $0 [start|stop] <service-name-in-small-caps-letters>
	\n$(tput setaf 3)e.g.\n$0 start hdfs$(tput sgr 0)\n$(tput setaf 3)$0 stop hdfs$(tput sgr 0)
	\n$(tput setaf 2)Start/Stop service component:$(tput sgr 0) $0 [start|stop] <component-name-in-small-or-caps-letters> <hostname>$(tput sgr 0)
	\n$(tput setaf 3)e.g.\n$0 start webhcat_server sandbox.hortonworks.com$(tput sgr 0)\n$(tput setaf 3)$0 stop spark_jobhistoryserver sandbox.hortonworks.com$(tput sgr 0)
	\n$(tput setaf 2)Add/Remove service component:$(tput sgr 0) $0 [add|remove] <component-name-in-small-or-caps-letters> <hostname>$(tput sgr 0)
	\n$(tput setaf 3)e.g.\n$0 add webhcat_server sandbox.hortonworks.com$(tput sgr 0)\n$(tput setaf 3)$0 remove spark_jobhistoryserver sandbox.hortonworks.com$(tput sgr 0)
	\n$(tput setaf 2)Backup database for Ambari/Hive/Oozie:$(tput sgr 0) $0 backup [ambari|hive|oozie] <database-type> <database-host>$(tput sgr 0)
        \n$(tput setaf 3)e.g.\n$0 backup ambari postgresql sandbox.hortonworks.com$(tput sgr 0)\n$(tput setaf 3)$0 backup oozie mysql sandbox.hortonworks.com"$(tput sgr 0)
        exit
}

service_action()
{
	#1 - service action i.e. start/stop/restart
	curl -H 'X-Requested-By:ambari' -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -X PUT -d '{"RequestInfo": {"context" :"'"Putting All Services in $1 state"'"}, "ServiceInfo": {"state" : "'"$1"'"}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services
}	

list_installed_services()
{
	curl -s -H "X-Requested-By:ambari" -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services|grep href|cut -d':' -f2-|rev|cut -d'/' -f1|rev|cut -d'"' -f1|grep ^[A-Z] > /tmp/list_all_services
	curl -s -H "X-Requested-By:ambari" -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -X GET http://$AMBARI_HOST:8080/api/v1/hosts|grep host_name|cut -d':' -f2|cut -d'"' -f2|uniq > /tmp/list_all_hosts
		for host in `cat /tmp/list_all_hosts`;do echo -e "\n$(tput setaf 2)$host$(tput sgr 0)\n\n"; curl -s -H "X-Requested-By:ambari" -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$host/host_components|grep component_name|cut -d',' -f1|tr ':' '|';done > /tmp/list_host_components 
	if [ "$1" == "show" ]
	then
		echo -e "\n$(tput setaf 2)Below is the list of installed services in your cluster:\n$(tput sgr 0)"
		cat /tmp/list_all_services
		echo -e "\n########################### List of Host-wise installed components ###########################\n"
		cat /tmp/list_host_components
	fi
}

individual_service_action()
{
	#$1 - start/stop $2 - service name
	curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"'"Putting $2 in $1 state"'"}, "Body": {"ServiceInfo": {"state": "'"$1"'"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$2
}

host_component_action()
{
	#$1-star/stop $2-service component name $3-hostname
	curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"'"Putting $2 in $1 state"'"}, "HostRoles": {"state": "'"$1"'"}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$3/host_components/$2
}

add_remove_host_component()
{
	#$1-add/remove $2-service component name $3-hostname
	if [ "$1" == add ]
	then
		curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -i -H 'X-Requested-By: ambari' -X POST -d '{"host_components" : [{"HostRoles":{"component_name":"'"$2"'"}}] }' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts?Hosts/host_name=$3
		host_component_action INSTALLED $2 $3
		echo -e "\n$(tput setaf 2)Sleeping for 5 seconds before starting $2"$(tput sgr 0)
		sleep 5
		host_component_action STARTED $2 $3
	elif [ "$1" == remove ]
	then
		curl -u $AMBARI_ADMIN_USER:$AMBARI_ADMIN_PASSWORD -H "X-Requested-By: ambari" -X DELETE http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$3/host_components/$2
	fi
}

backup_db()
{
	#$1 - Service name $2 - database type $3 - database host

	if [ "$2" == "mysql" ]
	then
		echo -e "\n$(tput setaf 2)Please enter mysql db password for $1 user$(tput sgr 0)"
		mysqldump -h $3 -u"$1" -p $1 > ~/"$1"_db_backup_`date +%Y_%m_%d_%H_%M`.sql
	elif [ "$2" == "postgresql" ]
	then
		pg_dump -h $3 -W -U $1 $1 > ~/"$1"_db_backup_`date +%Y_%m_%d_%H_%M`.sql
	fi	
}

#Main starts here

if [ $# -eq 0 ]
then
	usage
fi

if [ $# -eq 1 -a "$1" == "startall" ]
then
	service_action "STARTED"
elif [ $# -eq 1 -a "$1" == "stopall" ]
then
        service_action "INSTALLED"
elif [ $# -eq 1 -a "$1" == "listall" ]
then
	list_installed_services show
elif [ $# -eq 2 -a "$1" == "start" ]
then
	SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
	list_installed_services
	grep -wq $SERVICE_NAME /tmp/list_all_services
	if [ $? -eq 0 ]
	then
		individual_service_action STARTED $SERVICE_NAME
	else
		echo -e "\nWrong service name!\n"
		usage
	fi
elif [ $# -eq 2 -a "$1" == "stop" ]
then
        SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
        list_installed_services
        grep -wq $SERVICE_NAME /tmp/list_all_services 
        if [ $? -eq 0 ]
        then
                individual_service_action INSTALLED $SERVICE_NAME
        else
                echo -e "\nWrong service name!\n"
                usage
        fi
elif [ $# -eq 3 -a "$1" == "start" ]
then
        SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
        list_installed_services
        grep -wq $SERVICE_NAME /tmp/list_host_components
	SERVICE_EXIST_STAT=$?
	grep -wq $3 /tmp/list_all_hosts
	HOST_EXIST_STAT=$?
        if [ $SERVICE_EXIST_STAT -eq 0 -a $HOST_EXIST_STAT -eq 0 ]
        then
                host_component_action STARTED $SERVICE_NAME $3 
        else
                echo -e "\nEither hostname or component name is wrong!\nPlease run script with listall to check hostnames and their components!\n"
                usage
        fi
elif [ $# -eq 3 -a "$1" == "stop" ]
then
        SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
        list_installed_services
        grep -wq $SERVICE_NAME /tmp/list_host_components
        SERVICE_EXIST_STAT=$?
        grep -wq $3 /tmp/list_all_hosts
        HOST_EXIST_STAT=$?
        if [ $SERVICE_EXIST_STAT -eq 0 -a $HOST_EXIST_STAT -eq 0 ]
        then
                host_component_action INSTALLED $SERVICE_NAME $3
        else
                echo -e "\nEither hostname or component name is wrong!\nPlease run script with listall to check hostnames and their components!\n"
                usage
        fi
elif [ $# -eq 3 -a "$1" == "add" ]
then
        SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
        grep -wq $3 /tmp/list_all_hosts
        HOST_EXIST_STAT=$?
        if [ $HOST_EXIST_STAT -eq 0 ]
        then
                add_remove_host_component add $SERVICE_NAME $3
        else
                echo -e "\nHostname provided is not listed under registered hosts!\nPlease run script with listall to check hostnames!\n"
                usage
        fi
elif [ $# -eq 3 -a "$1" == "remove" ]
then
        SERVICE_NAME=`echo $2|tr [a-z] [A-Z]`
        list_installed_services
        grep -wq $SERVICE_NAME /tmp/list_host_components
        SERVICE_EXIST_STAT=$?
        grep -wq $3 /tmp/list_all_hosts
        HOST_EXIST_STAT=$?
        if [ $SERVICE_EXIST_STAT -eq 0 -a $HOST_EXIST_STAT -eq 0 ]
        then
                add_remove_host_component remove $SERVICE_NAME $3
        else
                echo -e "\nEither hostname or component name is wrong!\nPlease run script with listall to check hostnames and their components!\n"
                usage
        fi
elif [ $# -eq 4 -a "$1" == "backup" -a "$3" == "mysql" -o "$3" == "postgresql" ]
then
	backup_db $2 $3 $4
else
	usage
fi
