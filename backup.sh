#!/bin/bash

# source: https://github.com/JurajMlich/ultimate-bash-backup-script-with-rotation
# author: Juraj Mlich <jurajmlich@gmail.com>
# usage:
# backup.sh /home/WHAT_TO_BACKUP /home/WHERE_TO_BACKUP 2x10h 10x5m 2dx4 1mx5
# in the second directory, subdirectories will be made for each period + temp directory

toExclude=()

# --------------
# PARSE PARAMS
# --------------
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
	--exclude)
	toExclude+=("--exclude=$2");
	shift # past argument
	shift # past value
	;;
	*)    # unknown option
	POSITIONAL+=("$1") # save it in an array for later
	shift # past argument
	;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
# --------------

# --------------
# BASE CONFIG
# -------------
dirToBackup=$(readlink -f $1)
backupDir=$(readlink -f $2)
date=$(date '+%Y-%m-%d')
hour=$(date '+%H-%M-%S')

#logFile=/home/juraj/Data/log/backup.log # absolute path

function log(){
	echo "$1"

	if [ ! -z $logFile ]
	then
		echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> $logFile	
	fi
}

if [ ! -d $backupDir ]
then
	log "The backup directory unavailable."
	exit 1
fi;


tempDir="$backupDir/temp"
 
# create or purge tempDir
[ ! -d $tempDir ] && mkdir $tempDir

# LOCKING
# ----------------------------------
LOCKFILE="$backupDir/backup.lock"
LOCKFD=99
 
# PRIVATE
_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }
 
# ON START
_prepare_locking
 
# PUBLIC
exlock_now()        { _lock xn; }  # obtain an exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain an exclusive lock
shlock()            { _lock s; }   # obtain a shared lock
unlock()            { _lock u; }   # drop a lock
 
# Avoid running more instances of the script
if ! exlock_now
then
	log "The script is already executing."
	exit 1
fi
# --------------------------------------

rm -rf "$tempDir/*"

function backupTo() {
	local to="$1"
	
	# since we do not want to compress the backup more times than needed
	# we store the path to already comprimed archive in the $backupFile variable
	# and in case it is available, we only copy the file
	if [ ! -z "$backupFile" ]
	then
		log "Duplicating the already made backup to $to."
		cp "$backupFile" "$to"
	else	
		# make the archive in temp directory so that if the script is cancelled in
		# the middle, the next execution of script does not think that the backup was
		# completed (we check when the last backup was done by finding a backup file
		# that was modified in less than x minutes)
		log "Making backup of $dirToBackup to $to."
		tar -cpvzf "$tempDir/archive.tar.gz" "${toExclude[@]}" -C "$dirToBackup" . > "$tempDir/tar.log"
		
		code=$?
		
		if [ ! $code -eq 0  ]
		then
			log "Error during compressing backup. Error code: $code";
			exit $code
		fi
		
		# remove the temp file that can be used to watch progress
		rm "$tempDir/tar.log"
		# move it to the right location
		mv "$tempDir/archive.tar.gz" "$to"
		backupFile="$to"

	fi
}

# first two parameters are paths
for period in "${@:3}"
do
	# split by x 
	IFS='x' read -r -a periodSplit <<< "$period"
	# how many of previous backups should be kept
	toKeepAmount=${periodSplit[0]}
	# interval itself (e.g. 2h)
	interval=${periodSplit[1]}
	# numeric part of interval (e.g. 2)	
	intervalNumeric=$(echo "$interval" | tr -dc '0-9')
	# path where to store the backup
	path=$backupDir/$period
	
	if [[ $interval == *"h" ]]
	then
		backupName="$date $hour.tar.gz"
		intervalInMins=$(($intervalNumeric * 60))
	else
		backupName="$date.tar.gz"
		
		if [[ $interval == *"d" ]]
		then
			intervalInMins=$(($intervalNumeric * 60 * 24))
		elif [[ $interval == *"m" ]]
		then
			intervalInMins=$(($intervalNumeric * 60 * 24 * 30))
		else
			intervalInMins=$intervalNumeric
		fi
	fi

	# check if backup is not already done and do not continue if it is 
	if [ ! -d "$path" ] 	
	then
		# if the directory does not exist, let the flow continue as the 
		# the backup obviously does not exist
		mkdir "$path";
	else
		created=$(find $path -maxdepth 1 -mmin -$((intervalInMins)) -type f | wc -l)

		# if the backup exists, process to the next backup period
		if [[ $created -gt 0 ]]
		then
			continue
		fi
	fi

	# remove old backups	
	count=$(ls "$path" -Aq | wc -l)

	if [ $count -gt $((toKeepAmount - 1)) ]
	then
		log "Removing old backups from $path."
		ls $path -t -1 | tail -n -$(($count - $toKeepAmount + 1)) | xargs printf -- "$path/%s\n" | xargs -d '\n' rm -rf
	fi

	# make new backup
	backupTo "$path/$backupName"
done

rm -rf $tempDir
