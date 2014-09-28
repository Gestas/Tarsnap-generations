#!/usr/bin/env bash

# turn on debug
#exec 1>/tmp/tarsnap-generations_sh_trace.log 2>&1
#set -o xtrace 

#See README @ http://github.com/Gestas/Tarsnap-generations/blob/master/README

#########################################################################################
#What day of the week do you want to take the weekly snapshot? Default = Friday(5)	#
WEEKLY_DOW=5 										#
#Do you want to use UTC time? (1 = Yes) Default = 0, use local time.			#
USE_UTC=0										#
#Path to GNU date binary (e.g. /bin/date on Linux, /usr/local/bin/gdate on FreeBSD)	#
DATE_BIN=`which date`									#
TARSNAP_BIN='/usr/local/bin/tarsnap'                                                    #
#########################################################################################
usage ()
{
cat << EOF
usage: $0 arguments

This script manages Tarsnap backups

ARGUMENTS:
	 ?   Display this help.    
	-f   Path to a file with a list of folders to be backed up. List should be \n delimited.  
	-d   Number of daily backups to retain.
	-w   Number of weekly backups to retain.
	-m   Number of monthly backups to retain.
        -q   Be quiet - only output if something goes wrong

For more information - http://github.com/Gestas/Tarsnap-generations/blob/master/README
EOF
}

#Declaring helps check for errors in the user-provided arguments. See line #69.
declare -i DAILY_CNT
declare -i WEEKLY_CNT
declare -i MONTHLY_CNT
declare -i QUIET

QUIET=0

#Get the command line arguments. Much nicer this way than $1, $2, etc. 
while getopts ":f:d:w:m:q" opt ; do
	case $opt in
		f ) PATHS=$OPTARG ;;
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
if ( [ -z "$PATHS" ] || [ -z "$DAILY_CNT" ] || [ -z "$WEEKLY_CNT" ] || [ -z "$MONTHLY_CNT" ] ) 
then
	echo "-f, -d, -w, -m are not optional."
	usage
	exit 1
fi

if [ ! -f $PATHS ]
then
        echo "Couldn't find file $PATHS"
        usage
        exit 1
fi

#Check that $DAILY_CNT, $WEEKLY_CNT, $MONTLY_CNT are numbers.
if ( [ $DAILY_CNT = 1 ] || [ $WEEKLY_CNT = 1 ] || [ $MONTHLY_CNT = 1 ] )
then
	echo "-d, -w, -m must all be numbers greater than 0."
	usage
	exit 1
fi

#Set some constants
#The day of the week (Monday = 1, Sunday = 7)
DOW=$($DATE_BIN +%u)
#The calendar day of the month
DOM=$($DATE_BIN +%d)
#We need 'NOW' to be constant during execution, we set it here.
NOW=$($DATE_BIN +%Y%m%d-%H)
CUR_HOUR=$($DATE_BIN +%H)
if [ "$USE_UTC" = "1" ] ; then
	NOW=$($DATE_BIN -u +%Y%m%d-%H)
	CUR_HOUR=$($DATE_BIN -u +%H)
fi

#Find the backup type (DAILY|WEEKLY|MONTHY)
BK_TYPE=DAILY
if [ "$DOM" = "1" ] ; then
	BK_TYPE=MONTHLY
else
        if [ "$DOW" = "$WEEKLY_DOW" ] ; then
        	BK_TYPE=WEEKLY
        fi
fi

#Take the backup with the right name 
if [ $QUIET != "1" ] ; then
    echo "Starting $BK_TYPE backups..."
fi

# remove space from the field delimiters that are used in the for loops
# this allows to backup directory names with spaces
OLD_IFS=$IFS
IFS=$(echo -en "\n\b")

for dir in $(cat $PATHS) ; do
	$TARSNAP_BIN -c -f $NOW-$BK_TYPE-$(hostname -s)-$(echo $dir) --one-file-system -C / $dir
	if [ $? = 0 ] ; then
	    if [ $QUIET != "1" ] ; then
		echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo $dir) backup done."
	    fi
	else
		echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo $dir) backup error. Exiting" ; exit $?
	fi
done	


#Check to make sure the last set of backups are OK.
if [ $QUIET != "1" ] ; then
    echo "Verifying backups, please wait."
fi

archive_list=$($TARSNAP_BIN --list-archives)

for dir in $(cat $PATHS) ; do
	case "$archive_list" in
		*"$NOW-$BK_TYPE-$(hostname -s)-$(echo $dir)"* )
		if [ $QUIET != "1" ] ; then
		    echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo $dir) backup OK."
		fi ;;
		* ) echo "$NOW-$BK_TYPE-$(hostname -s)-$(echo $dir) backup NOT OK. Check --archive-list."; exit 3 ;; 
	esac
done

#Delete old backups
DAILY_DELETE_TIME=$($DATE_BIN -d"-$DAILY_CNT day" +%Y%m%d-%H)
WEEKLY_DELETE_TIME=$($DATE_BIN -d"-$WEEKLY_CNT week" +%Y%m%d-%H)
MONTHLY_DELETE_TIME=$($DATE_BIN -d"-$MONTHLY_CNT month" +%Y%m%d-%H)

if [ $QUIET != "1" ] ; then
    echo "Finding backups to be deleted."
fi


if [ $BK_TYPE = "DAILY" ] ; then
        for backup in $archive_list ; do
                case "$backup" in
                         "$DAILY_DELETE_TIME-$BK_TYPE"* )
					 case "$backup" in
                                                *"$NOW"* ) echo "Skipped $backup" ;;
                                                * )  $TARSNAP_BIN -d -f $backup
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
                                                * ) $TARSNAP_BIN -d -f $backup
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
                                                * ) $TARSNAP_BIN -d -f $backup
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

# restore old IFS value
IFS=$OLD_IFS

if [ $QUIET != "1" ] ; then
    echo "$0 done"
fi
