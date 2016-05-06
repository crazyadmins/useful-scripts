#!/bin/bash
#Script developed by - Kuldeep Kulkarni (http://crazyadmins.com)
#######################################

echo -e "Please wait while we calculate size to determine top 10 directories on HDFS"
for dir in `hadoop fs -ls /|awk '{print $8}'`;do hadoop fs -du $dir/* 2>/dev/null;done|sort -nk1|tail -10 > /tmp/size.txt
echo "|  ---------------------------          |  -------        |  ------------  |  ---------     |  ----------     ------  |" > /tmp/tmp
echo "| Dir_on_HDFS | Size_in_MB | User | Group | Last_modified Time |" >> /tmp/tmp
echo "|  ---------------------------          |  -------        |  ------------  |  ---------     |  ----------     ------  |" >> /tmp/tmp
while read line;
do
        size=`echo $line|cut -d' ' -f1`
        size_mb=$(( $size/1048576 ))
        path=`echo $line|cut -d' ' -f2`   #(Please use -f3 if running on cloudera)
        dirname=`echo $path|rev|cut -d'/' -f1|rev`
        parent_dir=`echo $path|rev|cut -d'/' -f2-|rev`
        fs_out=`hadoop fs -ls $parent_dir|grep -w $dirname`
        user=`echo $fs_out|grep $dirname|awk '{print $3}'`
        group=`echo $fs_out|grep $dirname|awk '{print $4}'`
        last_mod=`echo $fs_out|grep $dirname|awk '{print $6,$7}'`
        echo "| $path | $size_mb | $user | $group | $last_mod |" >> /tmp/tmp
done < /tmp/size.txt

cat /tmp/tmp | column -t
