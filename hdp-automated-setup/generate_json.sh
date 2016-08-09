#!/bin/bash
########
# Author: Kuldeep Kulkarni 
# Description: This script does the Magic of automating HDP install using Ambari Blueprints
#set -x

#Globals
LOC=`pwd`
PROPS=$1
#Source props
source $LOC/$PROPS 2>/dev/null
STACK_VERSION=`echo $CLUSTER_VERSION|cut -c1-3`
AMBARI_HOST=$2
NUMBER_OF_HOSTS=`grep HOST $LOC/$PROPS|grep -v SERVICES|wc -l`
LAST_HOST=`grep HOST $LOC/$PROPS|grep -v SERVICES|head -n $NUMBER_OF_HOSTS|tail -1|cut -d'=' -f2`
grep HOST $LOC/$PROPS|grep -v SERVICES|grep -v $LAST_HOST|cut -d'=' -f2 > $LOC/list
OS_VERSION=`echo $OS|rev|cut -c1|rev`

#Generate hostmap function#

hostmap()
{
#Start of function

echo "{
  \"blueprint\" : \"$CLUSTERNAME\",
  \"default_password\" : \"$DEFAULT_PASSWORD\",
  \"host_groups\" :["

for HOST in `cat list`
do
   echo "{
      \"name\" : \"$HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$HOST.$DOMAIN_NAME\"
        }
      ]
    },"
done

echo "{
      \"name\" : \"$LAST_HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$LAST_HOST.$DOMAIN_NAME\"
        }
      ]
    }
  ]
}"

#End of function
}

clustermap()
{
#Start of function
LAST_HST_NAME=`grep 'HOST[0-9]*' $LOC/$PROPS|grep -v SERVICES|tail -1|cut -d'=' -f1`

echo "{
  \"configurations\" : [ ],
  \"host_groups\" : ["

for HOST in `grep -w 'HOST[0-9]*' $LOC/$PROPS|tr '\n' ' '`
do
   HST_NAME_VAR=`echo $HOST|cut -d'=' -f1`
   echo "{
      \"name\" : \"`grep $HST_NAME_VAR $PROPS |head -1|cut -d'=' -f2|cut -d'.' -f1`\",
      \"components\" : ["
		LAST_SVC=`grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|rev|cut -d' ' -f1|rev|cut -d'"' -f1`
		for SVC in `grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|cut -d'"' -f2|cut -d'"' -f1`
		do
        		echo "{
			\"name\" : \"$SVC\""
			if [ "$SVC" == "$LAST_SVC" ]
			then
				echo "}
				],
      			        \"cardinality\" : "1""
				if [ "$HST_NAME_VAR" == "$LAST_HST_NAME" ]
				then
    	               		    	echo "}"
				else
					echo "},"
				fi
			else
       	 				echo "},"
			fi
		done
done

echo "  ],
  \"Blueprints\" : {
    \"blueprint_name\" : \"$CLUSTERNAME\",
    \"stack_name\" : \"HDP\",
    \"stack_version\" : \"$STACK_VERSION\"
  }
}"


#End of function
}


repobuilder()
{
#Start of function
BASE_URL="http://$REPO_SERVER/hdp/$OS/HDP-$CLUSTER_VERSION/"


echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL\",
   \"verify_base_url\" : true
}
}" > $LOC/repo.json

BASE_URL_UTILS="http://$REPO_SERVER/hdp/$OS/HDP-UTILS-$UTILS_VERSION/"

export BASE_URL_UTILS;

echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL_UTILS\",
   \"verify_base_url\" : true
}
}" > $LOC/repo-utils.json

#End of function
}

timestamp()
{
#Function to print timestamp

echo "`date +%Y-%m-%d-%H:%M:%S`"
}

installhdp()
{
#Install hdp using Ambari Blueprints

HDP_UTILS_VERSION=`echo $BASE_URL_UTILS| awk -F'/' '{print $6}'`

curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/blueprints/$CLUSTERNAME -d @"$LOC"/cluster_config.json
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/HDP-$STACK_VERSION -d @$LOC/repo.json
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/$HDP_UTILS_VERSION -d @$LOC/repo-utils.json
sleep 1
curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTERNAME -d @$LOC/hostmap.json

}

#################
# Main function #
################

#Generate hostmap
printf "`timestamp` Generating hostmap json.."
hostmap > $LOC/hostmap.json
echo "`timestamp` Saved $LOC/hostmap.json"

#Generate cluster config json
printf "`timestamp` Generating cluster configuration json"
clustermap > $LOC/cluster_config.json
echo "`timestamp` Saved $LOC/cluster_config.json"

#Create internal repo json 
repobuilder 
printf "`timestamp` Generating internal repositories json..\n`timestamp` Saved $LOC/repo.json & $LOC/repo-utils.json"

#Start hdp installation
installhdp
