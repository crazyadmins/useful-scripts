#!/bin/bash
#Author - KK [ Kuldeep Kulkarni ]
#Website - http://crazyadmins.com
#Note - nc-1.84-22.el6.x86_64 or greater version of netcat package is required in order to get this script working!

#Globals
################################
ZOOKEEPER_CONF="/etc/zookeeper/conf/zoo.cfg"
HOSTNAME=`hostname`
ZK_CLIENT_PORT=`grep clientPort $ZOOKEEPER_CONF|cut -d'=' -f2`
DATE=`date +%d-%m-%Y,%H:%M:%S`
ZK_MODE=`echo stat | nc $HOSTNAME $ZK_CLIENT_PORT | grep Mode | cut -d':' -f2|tr -d ' '`
TOTAL_CONNECTIONS=`netstat -aplnut|grep ":$ZK_CLIENT_PORT"|egrep 'ESTABLISHED|CLOSED_WAIT'|wc -l`
LOG=/root/zk_connections.log
################################

if [ "$ZK_MODE" == " " ]
then
        echo "$DATE Looks like this host($HOSTNAME) is not zookeeper host or zookeeper service is not running!"| tee -a $LOG
        exit
else
        echo "$DATE This zookeeper node($HOSTNAME) is $ZK_MODE" | tee -a $LOG
        echo -e "$DATE Total number of established connections are : $TOTAL_CONNECTIONS" | tee -a $LOG
fi
