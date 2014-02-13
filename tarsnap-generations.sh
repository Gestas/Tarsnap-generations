#!/usr/bin/env bash

#See README @ http://github.com/Gestas/Tarsnap-generations/blob/master/README

#########################################################################################
#What day of the week do you want to take the weekly snapshot? Default = Friday(5)	#
WEEKLY_DOW=5 										#
#What hour of the day to you want to take the daily snapshot? Default = 11PM (23)	#
DAILY_TIME=23										#
#Do you want to use UTC time? (1 = Yes) Default = 0, use local time.			#
USE_UTC=0										#
#Path to GNU date binary (e.g. /bin/date on Linux, /usr/local/bin/gdate on FreeBSD)	#
DATE_BIN=`which date`									#
#########################################################################################
usage ()
{
cat << EOF
usage: $0 arguments

This script manages Tarsnap backups

ARGUMENTS:
	 ?   Display this help.    
	-f   Path to a file with a list of folders to be backed up. List should be \n delimited.  
	-h   Number of hourly backups to retain.
	-d   Number of daily backups to retain.
	-w   Number of weekly backups to retain.
	-m   Number of monthly backups to retain.
        -q   Be quiet - only output if something goes wrong

For more information - http://github.com/Gestas/Tarsnap-generations/blob/master/README
EOF
}

#Declaring helps check for errors in the user-provided arguments. See line #69.
declare -i HOURLY_CNT
declare -i DAILY_CNT
declare -i WEEKLY_CNT
declare -i MONTHLY_CNT
declare -i QUIET

QUIET=0

#Get the command line arguments. Much nicer this way than $1, $2, etc. 
while getopts ":f:h:d:w:m:q" opt ; do
	case $opt in
		f ) PATHS=$OPTARG ;;
		h ) HOURLY_CNT=$(($OPTARG+1)) ;;
		d ) DAILY_CNT=$(($OPTARG+1)) ;;
		w ) WEEKLY_CNT=$(($OPTARG+1)) ;;
		m ) MONTHLY_CNT=$(($OPTARG+1)) ;;
	        q ) QUIET=1 ;;
		\?) echo \n $usage
			exit 1 ;;
		 *) echo \n $usage
			exit 1 ;;	
	esac
done

#Check arguments
if ( [ -z "$PATHS" ] || [ -z "$HOURLY_CNT" ] || [ -z "$DAILY_CNT" ] || [ -z "$WEEKLY_CNT" ] || [ -z "$MONTHLY_CNT" ] ) 
then
	echo "-f, -h, -d, -w, -m are not optional."
	usage
	exit 1
fi

if [ ! -f $PATHS ]
then
        echo "Couldn't find file $PATHS"
        usage
        exit 1
fi

#Check that $HOURLY_CNT, $DAILY_CNT, $WEEKLY_CNT, $MONTLY_CNT are numbers.
if ( [ $HOURLY_CNT = 1 ] || [ $DAILY_CNT = 1 ] || [ $WEEKLY_CNT = 1 ] || [ $MONTHLY_CNT = 1 ] )
then
	echo "-h, -d, -w, -m must all be numbers greater than 0."
	usage
	exit 1
fi

#Set some constants
#The day of the week (Monday = 1, Sunday = 7)
DOW=$($DATE_BIN +%u)
#The calendar day of the month
DOM=$($DATE_BIN +%d)
#The last day of the current month. I wish there was a better way to do this, but this seems to work everywhere. 
LDOM=$(echo $(cal) | awk '{print $NF}')
#We need 'NOW' to be constant during execution, we set it here.
NOW=$($DATE_BIN +%Y%m%d-%H)
CUR_HOUR=$($DATE_BIN +%H)
if [ "$USE_UTC" = "1" ] ; then
	NOW=$($DATE_BIN -u +%Y%m%d-%H)
	CUR_HOUR=$($DATE_BIN -u +%H)
fi

#Find the backup type (HOURLY|DAILY|WEEKLY|MONTHY)
BK_TYPE=HOURLY	#Default to HOURLY
if ( [ "$DOM" = "$LDOM" ] && [ "$CUR_HOUR" = "$DAILY_TIME" ] ) ; then
	BK_TYPE=MONTHLY
else
        if ( [ "$DOW" = "$WEEKLY_DOW" ] && [ "$CUR_HOUR" = "$DAILY_TIME" ] ) ; then
        	BK_TYPE=WEEKLY
	else
                if [ "$CUR_HOUR" = "$DAILY_TIME" ] ; then
			BK_TYPE=DAILY
                fi
        fi
fi

#Take the backup with the right name 
if [ $QUIET != "1" ] ; then
    echo "Starting $BK_TYPE backups..."
fi

for dir in $(cat $PATHS) ; do
	tarsnap -c -f $NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.}) --one-file-system -C / $dir
	if [ $? = 0 ] ; then
	    if [ $QUIET != "1" ] ; then
		echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.}) backup done."
	    fi
	else
		errcode=$?
		echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.}) backup error. Exiting" ; exit $errcode
	fi
done	

#Check to make sure the last set of backups are OK.
if [ $QUIET != "1" ] ; then
    echo "Verifying backups, please wait."
fi

archive_list=$(tarsnap --list-archives)

for dir in $(cat $PATHS) ; do
	case "$archive_list" in
		*"$NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.})"* )
		if [ $QUIET != "1" ] ; then
		    echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.}) backup OK."
		fi ;;
		* ) echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo ${dir//\//.}) backup NOT OK. Check --archive-list."; exit 3 ;; 
	esac
done

#Delete old backups
HOURLY_DELETE_TIME=$($DATE_BIN -d"-$HOURLY_CNT hour" +%Y%m%d-%H) 
DAILY_DELETE_TIME=$($DATE_BIN -d"-$DAILY_CNT day" +%Y%m%d-%H)
WEEKLY_DELETE_TIME=$($DATE_BIN -d"-$WEEKLY_CNT week" +%Y%m%d-%H)
MONTHLY_DELETE_TIME=$($DATE_BIN -d"-$MONTHLY_CNT month" +%Y%m%d-%H)

if [ $QUIET != "1" ] ; then
    echo "Finding backups to be deleted."
fi

if [ $BK_TYPE = "HOURLY" ] ; then
	for backup in $archive_list ; do
		case "$backup" in
			 "$HOURLY_DELETE_TIME-$BK_TYPE"* ) 	
					case "$backup" in   #this case added to make sure the script doesn't delete the backup it just took. Case: '-h x' and backup takes > x hours. 
						*"$NOW"* ) echo "Skipped $backup" ;;
						* )  tarsnap -d -f $backup
							if [ $? = 0 ] ; then
							    if [ $QUIET != "1" ] ; then
              							echo "$backup snapshot deleted."
							    fi
     					   		else
           							echo "Unable to delete $backup. Exiting" ; exit $?
        						fi ;;
					esac ;;
			* ) ;;
		esac
 	done
fi


if [ $BK_TYPE = "DAILY" ] ; then
        for backup in $archive_list ; do
                case "$backup" in
                         "$DAILY_DELETE_TIME-$BK_TYPE"* )
					 case "$backup" in
                                                *"$NOW"* ) echo "Skipped $backup" ;;
                                                * )  tarsnap -d -f $backup
                                       			 if [ $? = 0 ] ; then
							     if [ $QUIET != "1" ] ; then 
                                                		echo "$backup snapshot deleted."
							     fi
                                           		else
                                                		echo "Unable to delete $backup. Exiting" ; exit $?
                                        		fi ;;
					 esac ;;
                        * ) ;;
                esac
        done
fi

if [ $BK_TYPE = "WEEKLY" ] ; then
        for backup in $archive_list ; do
                case "$backup" in
                         "$WEEKLY_DELETE_TIME-$BK_TYPE"* ) 
					 case "$backup" in
                                                *"$NOW"* ) echo "Skipped $backup" ;;
                                                * ) tarsnap -d -f $backup
                                        		if [ $? = 0 ] ; then
							    if [ $QUIET != "1" ] ; then
                                                		echo "$backup snapshot deleted."
							    fi
                                           		else
                                                		echo "Unable to delete $backup. Exiting" ; exit $?
                                        		fi ;;
					esac ;;
                        * ) ;;
                esac
        done
fi

if [ $BK_TYPE = "MONTHLY" ] ; then
        for backup in $archive_list ; do
                case "$backup" in
                         "$MONTHLY_DELETE_TIME-$BK_TYPE"* ) 
					 case "$backup" in
                                                *"$NOW"* ) echo "Skipped $backup" ;;
                                                * ) tarsnap -d -f $backup
                                        		if [ $? = 0 ] ; then
							    if [ $QUIET != "1" ] ; then
                                                		echo "$backup snapshot deleted."
							    fi
                                           		else
                                                		echo "Unable to delete $backup. Exiting" ; exit $?
                                        		fi ;;
					esac ;;
                        * ) ;;
                esac
        done
fi
if [ $QUIET != "1" ] ; then
    echo "$0 done"
fi
