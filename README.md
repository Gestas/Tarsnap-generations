####NAME
tarsnap-generations  

####SYNOPSIS
Cycles [Tarsnap](https://tarsnap.com/ "Tarsnap") backups in a grandfather-father-son scheme.

####USAGE
The script is designed to be run via crontab or equivalent.
```gherkin
    tarsnap-generations.sh

        ARGUMENTS:
             ?   Display this help.    
            -f   Path to a file with a list of folders to be backed up. List should be newline delimited.  
            -d   Number of daily backups to retain.
            -w   Number of weekly backups to retain.
            -m   Number of monthly backups to retain.
            -q   Be quiet - limits output unless something goes wrong.
```

####DESCRIPTION
The script is designed to be run via crontab. It expects five inputs and a working Tarsnap configuration file (see below).


####REQUIRES
The tarsnap-generations requires a .tarsnaprc or tarsnap.conf that specifies at least these options -  
```gherkin
    keyfile <path to keyfile>  
    cachedir <path to cache dir>  
    exclude <path to cache dir>  
    humanize-numbers
```
See [the Tarsnap documentation](http://www.tarsnap.com/man-tarsnap.conf.5.html "tarsnap.conf") for more details.

####CRONTAB EXAMPLES 	
```gherkin
    15 * * * * tarsnap-generations.sh -f /root/tarsnap.folders -d 30 -w 12 -m 24
```
Takes a backup every hour at the :15, keeps 36 hours of hourly backups, 30 days of daily backups, 12 weeks of weekly backups and 2 years of monthly backups.
```gherkin
    30 23 * * * tarsnap-generations.sh -f /root/tarsnap.folders -d 10 -w 4 -m 2
```
No hourly backups, a daily backup at 23:30, keeps 10 days of daily backups, 4 weeks of weekly backups and 2 months of monthly backups. Note that the hour here (23) must match the hour set by $DAILY_TIME, line 9 of the script. 23 (11PM) is the default.

####ERRORS
IMPORTANT: the deletion of old backups is broken atm  
Script will fail silently if you supply unsupported arguments  
The script will exit with a non 0 error code if a backup fails or can't be verified. Be sure to pay attention. 

####TROUBLESHOOTING
Tarsnap needs to be working properly for tarsnap-generations to work. To quickly test if Tarsnap is working -  
```gherkin
    $ tarsnap -c -f test-backup-1 /sbin    # This will take a backup of the /sbin directory.
```    
If there are no errors then let's make sure the archive was created -  
```gherkin
    $ tarsnap --list-archives    # This will list all of the existing backups. 
    test-backup-1    # If the backup we just created is listed then Tarsnap is woring properly.
```
If any of those steps failed see [the Tarsnap getting started documentation](https://www.tarsnap.com/gettingstarted.html "Getting started with Tarsnap") for help.

Be sure to delete the test backup, you are being charged for it!
```gherkin
    $ tarsnap -d -f test-backup-1
```

####AUTHOR
craig@gestas.net

####WITH THANKS TO
https://tarsnap.com  
http://www.bluebottle.net.au/blog/2009/tarsnap-backups-on-windows-and-linux  
https://en.wikipedia.org/wiki/Grandfather-father-son_backup
