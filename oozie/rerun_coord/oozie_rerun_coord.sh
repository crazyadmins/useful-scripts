#!/bin/bash
#Script Developed by Kuldeep Kulkarni (Hortonworks Inc.)
##############################

LOC="/root"
source $LOC/oozie.props

ts()
{
	echo "`date +%Y-%m-%d,%H:%M:%S`"
}

check_status()
{

##############
#If last action's status is KILLED then this script will re-run the last action and will exit. If not, it will keep checking the status and will sleep for $SLEEP_INTERVAL seconds mentioned in oozie.props
##############

	oozie job -len 10000 -info $COORD_ID|grep -v ^"-"|tail -1 > $TMP_FILE
	status_last_action=`cat $TMP_FILE|awk '{print $2}'`
	action_id=`cat $TMP_FILE|awk '{print $1}'|cut -d'@' -f2`
	if [ "$status_last_action" == "KILLED" ]
	then
		echo "`ts` Job status for "$COORD_ID"@"$action_id" is $status_last_action, Moving ahead with re-run"
		oozie job -rerun $COORD_ID -action $action_id
		rerun_stat=$?
		echo "`ts` Exit status of rerun is $rerun_stat, Terminating the script"
		exit 0
	else
		echo "`ts` Job status for "$COORD_ID"@"$action_id" is $status_last_action, Sleeping for $SLEEP_INTERVAL second(s)"
		sleep $SLEEP_INTERVAL
	fi
}


for ((;;))
do
	check_status >> $LOG_FILE
done
