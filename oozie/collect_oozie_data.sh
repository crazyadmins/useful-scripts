#!/bin/bash
#Script to collect Oozie launcher logs/application logs and configs
#Author - Kuldeep Kulkarni (Hortonworks Inc.)
#############################################

getjobinfo()
{
        echo -e "\nPlease wait..Saving job info for $1 at "$LOC"/"$1"/"$1".info"
        oozie job -info $1 -verbose > "$LOC"/"$1"/"$1".info
	if [ $? -ne 0 ]
	then
		echo -e "\nError occurred while checking workflow status for $1.\nPlease check the workflow ID and try again!"
		exit 1
	fi
}

getlogs()
{
        launcher_job_id=`grep application_ "$LOC"/"$1"/"$1".info|awk '{print $2}'|rev|cut -d'/' -f2|rev`
        echo -e "\nSaving application logs for Oozie laucher - $launcher_job_id at "$LOC"/"$1"/"$launcher_job_id".log"
        yarn logs -applicationId $launcher_job_id > "$LOC"/"$1"/"$launcher_job_id".log 2>>$LOGFILE
	if [ $? -ne 0 ]
	then
		echo -e "\nError occurred while fetching yarn logs for "$launcher_job_id"\nPlease check $LOGFILE for more details"
		exit 1
	else
		echo -e "\nSuccessfully saved yarn logs for "$launcher_job_id" at "$LOC"/"$1"/"$launcher_job_id".log"
	fi
        echo -e "\nSearching for child job in launcher logs"
        child_job_id=`grep 'Submitted application' "$LOC"/"$1"/"$launcher_job_id".log|rev|awk '{print $1}'|rev`
        echo -e "\nFound child job triggered by launcher - "$child_job_id"\n\nSaving application logs for child job at "$LOC"/"$1"/"$child_job_id".log"
	yarn logs -applicationId $child_job_id > "$LOC"/"$1"/"$child_job_id".log 2>>$LOGFILE
	if [ $? -ne 0 ]
        then
                echo -e "\nError occurred while fetching yarn logs for "$child_job_id"\nPlease check $LOGFILE for more details"
                exit 1
        else
                echo -e "\nSuccessfully saved yarn log for "$child_job_id" at "$LOC"/"$1"/"$child_job_id".log"
        fi

}

getjobconfigs()
{
	echo -e "\nCollecting job.properties and workflow.xml"
	oozie job -configcontent $1 > "$LOC"/"$1"/"$1".job.xml 2>>$LOGFILE
	if [ $? -ne 0 ]
	then
		echo -e "\nError occurred while fetching job.xml for $1"
		exit 1
	else
		echo -e "\nSuccessfully saved job.xml at "$LOC"/"$1"/"$1".job.xml"
	fi
	oozie job -definition $1 > "$LOC"/"$1"/"$1".workflow.xml 2>>$LOGFILE
        if [ $? -ne 0 ]
        then
                echo -e "\nError occurred while fetching workflow.xml for $1"
                exit 1
	else
		echo -e "\nSuccessfully saved workflow.xml at "$LOC"/"$1"/"$1".workflow.xml"
        fi
}

getoozieconfigs()
{
	echo -e "\nCopying oozie config files from $OOZIE_CONF_DIR to $LOC/$1/oozie_configs directory"
	if [ ! -d ""$LOC"/"$1"/oozie_configs" ]
	then
		mkdir $LOC/$1/oozie_configs
	fi
	cp -rp $OOZIE_CONF_DIR/* $LOC/$1/oozie_configs/
}

getoozielogs()
{
	echo -e "\nCopying oozie logs from $OOZIE_LOG_DIR to $LOC/$1/oozie_logs directory"
	if [ ! -d ""$LOC"/"$1"/oozie_logs" ]
	then
		mkdir $LOC/$1/oozie_logs
	fi
	cp -rp $OOZIE_LOG_DIR/oozie.log $OOZIE_LOG_DIR/catalina.out $OOZIE_LOG_DIR/oozie-instrumentation.log $LOC/$1/oozie_logs/
}

collectdata()
{
	echo -e "\nCompressing the collected data and creating tarball"
	tar -zcvf "$LOC"/"$1".tar.gz "$LOC"/"$1"
	if [ $? -ne 0 ]
	then
		echo -e "\nError occurred while running tar command, please check $LOGFILE for more details!"
		exit 1
	else
		echo -e "\nSuccessfully saved tarball at "$LOC"/"$1".tar.gz \nPlease attach it to the Salesforce Case and inform Hortonworks Support team.\nThank you!"
	fi
}

if [ $# -ne 1 ]
then
        echo -e "Usage: $0 <wf-id>\nE.g. $0 0000001-180423183658172-oozie-oozi-W"
        exit 1
fi

LOC=$PWD
if [ ! -d "$LOC"/"$1" ]
then
	mkdir $LOC/$1
fi
LOGFILE=$LOC/$1/oozie_data_collection.log
>$LOGFILE

if [ ! -f $LOC/oozie.props ]
then
	echo "$LOC/oozie.props not found! Please copy oozie.props file and try again."
	exit 1
fi

source $LOC/oozie.props
export OOZIE_URL=$OOZIE_URL
getjobinfo $1
getlogs $1
getjobconfigs $1
getoozieconfigs $1
getoozielogs $1
collectdata $1
