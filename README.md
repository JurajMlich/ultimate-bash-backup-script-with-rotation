# Bash backup script supporting rotation
After looking around the whole internet, I had not found a script that would have been general enough and would have worked exactly as I want. So I have learned Bash and here is the result. Feel free to correct my mistakes, if any. Script was carefully tested. 

## Features
- configuration of more backup intervals
- removal of old backups
- irregular script execution
- informative logging
- error proof

## Usage & details
Example: `backup.sh DIRECTORY_TO_BACKUP DIRECTORY_TO_STORE_BACKUP_IN 10x5 7x2h 5x4m`
- 10x5, 7x2h, 5x4m define intervals in which backups should be stored
  - the first part defines how many of old backups should be stored (if you have more, they'll get removed during execution of the script)
  - the second part defines the interval in which the backups should be made (every 5 minutes,  every 2 hours,  every 4 months)
     - without suffix: minutes
     - h: hours
     - m: months
  - you can have as many intervals as you want
- in case your interval is minute or hour specific, the filename of the backup will contain the time as well
- the script operates on date of modification ---> do not modify date of modification yourself
- if another instance of the script is started, it will terminate so that we don't have two parallel executions of the same backup
- if the script is forced to stop in the middle of the process, nothing will happen as the backup is being made in "temp" directory and moved to final destination only if compressed successfully 
- if you specify more intervals and the backup should be made for more intervals, the comprimation will be done only once
- you can run the script as many times as you want, the backup will be made only when necessary 
 
 ## Logging
 Set logDir variable in the script to the file you want log messages to be written in.
 
 ## Exluding dirs
 You may exclude files by applying --exclude xxx options, where xxx is **relative path from the directory you are backuping**. 
 
 ## Cron example
 `*/5 * * * * ~/Data/bin/backup.sh ~/.local/nottelo /media/backups/nottelo 10x1h 7x1d 3x1m`<br>
`*/20 * * * * ~/Data/bin/backup.sh ~ /media/backups/home 3x12h 7x1d 3x1m`
