#!/bin/bash
#Script developed by - Kuldeep Kulkarni (http://crazyadmins.com)
#This script can used to restore ambari database from existing dump file (Postgress DB only)
#######################

if [ $# -ne 1 ]
then
	echo "Usage $0 <complete-path-of-dump-file>"
	exit 1
fi

#Globals
LOC=`pwd`
TS=`date +%F-%H-%M-%S`

echo "drop database ambari;
create database ambari;
CREATE USER ambari WITH PASSWORD 'bigdata';
GRANT ALL PRIVILEGES ON DATABASE ambari TO ambari;
\connect ambari;
CREATE SCHEMA ambari AUTHORIZATION ambari;
ALTER SCHEMA ambari OWNER TO ambari;
ALTER ROLE ambari SET search_path to 'ambari', 'public';" > /tmp/db_commands

echo -e "\nTaking backup of existing Ambari DB just to be on safer side!"
pg_dump -W -U ambari ambari > "$LOC"/ambari-db-backup-"$TS".sql
echo -e "\nVerify if backup is successful by checking "$LOC"/ambari-db-backup-"$TS".sql file"
echo -e "\nPress any key to continue"
read

ambari-server stop
cat /tmp/db_commands|sudo -u postgres psql
echo -e "\nEnter database password for ambari user"
cat $1|psql -U ambari ambari
ambari-server start
ambari-agent restart
