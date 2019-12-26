#!/bin/bash

###############
#Main Variables (do not change)
###############
INSTALLERVERSION="1.0.0"
SCRIPTPATH="/root"
SENDREMINDER=true
STOPFAILED=false
PCTID=""
NEWIP=""
FAILEDPCTIDS=()
STARTAFTERRESTORE=false

###############
#Mail Variables
###############
MAILSENDER="email@email.de"
MAILRECIEVER="email@email.de"
MAILMESSAGE="Bitte den Titel beachten."

###############
#Text Functions
###############
function greenMessage {
  echo -e "\\033[32;1m${*}\033[0m"
}

function magentaMessage {
  echo -e "\\033[35;1m${*}\033[0m"
}

function cyanMessage {
  echo -e "\\033[36;1m${*}\033[0m"
}

function redMessage {
  echo -e "\\033[31;1m${*}\033[0m"
}

function yellowMessage {
  echo -e "\\033[33;1m${*}\033[0m"
}

#################
#Cleanup function - Removes the lock file and temporary directory
#################
function runCleanup {

  #Remove lockfile if it exists
  rm "$SCRIPTPATH/pctid.lock" >/dev/null 2>&1

  #Remove temporary working directory
  rm -rf $SCRIPTPATH/VMIDS >/dev/null 2>&1

}

##############
#Mail Function - Sends a mail from $MAILSENDER to $MAILRECIEVER with the title "Migration notice: $1" (as where $1 is the first parameter of the function call) and the message $MAILMESSAGE
##############
function sendanemail {

  #Send mail using the sendemail command
  sendemail -f "$MAILSENDER" -t "$MAILRECIEVER" -u "Migration notice: $1" -m "$MAILMESSAGE" -v -o message-charset=utf-8 >/dev/null 2>&1

}

#######################
#Lock aquiring function - Tries to aquire the lock for the backup process of the PCT ID $1
#######################
function aquireLock {

  yellowMessage "Aquiring lock for backup process of PCT ID $1"

    #Try to aquire the lock until the script exits or the lock is aquired
    while :
	do
        #Sleep for 2 seconds if the lock cannot be aquired
	    if [ -f "$SCRIPTPATH/pctid.lock" ]; then
          sleep 2
		else

		  #Exit the loop
		  break

        fi
	done

  #Aquire lock
  echo "$1" > pctid.lock
  greenMessage "Lock for backup process of PCT ID $1 aquired!"

}

######################
#Lock release function - Releases the lock
######################
function releaseLock {

  #Remove the lockfile
  rm "$SCRIPTPATH/pctid.lock"
  echo -ne "\n"

}

##########################
#Sync and Restore function - calls the sync and restore script as where $1 is the PCT ID, $2 the new IP address, $3 the new PCT ID, $DUMPDIR the directory where the backup is stored, $TARFILE the path to the backup and $STARTAFTERRESTORE a boolean if the PCT should be started after the restoration (depending on if the PCT was started before)
##########################
function syncAndRestore {

    #Check if PCT ID is in array of failed PCT IDs
    if [[ ! " ${FAILEDPCTIDS[@]} " =~ " $1 " ]]; then

        #Check if postbackup.pl created a file for the PCTID
        if [ -f "$SCRIPTPATH/VMIDS/$1" ]; then

          #Get directory of the backup path
          DUMPDIR=$(cat "$SCRIPTPATH/VMIDS/$1" | cut -d ";" -f2)

          #Get path of the backup file
          TARFILE=$(cat "$SCRIPTPATH/VMIDS/$1" | cut -d ";" -f3)
		  #Execute the syncandrestore script
          bash $SCRIPTPATH/syncandrestore.sh $2 $3 $DUMPDIR $TARFILE $STARTAFTERRESTORE

	    else

	      redMessage "Syncfile missing. (Probably because the backup task failed)"

	    fi

	fi

}

##################
#PCT Stop Function - Stops the PCT $1 and initiates the start of the PCT after restoration. If the function cannot stop the PCT correctly, it sends an E-Mail, initiates the skip of the createBackup and syncandRestore functions and adds the PCT ID to the array of failed backup PCT IDs.
##################
function stopPCT {

  yellowMessage "Stopping PCT ID $1..."

  #Stop PCT
  pct stop "$1" >/dev/null 2>&1

    #Stop if stopping PCT failed
	if [[ "$?" -eq 255 ]]; then

      yellowMessage "PCT not running. Continuing with backup task..."
	  sleep 1

	elif [[ "$?" -eq 0 ]]; then

      redMessage "Stopping PCT ID $1 failed. Manual intervention required. E-Mail was sent. Continuing with next backup."

      #Initiate skip of the createBackup and syncAndRestore functions
	  STOPFAILED=true

	  #Add PCT ID to the array of failed PCT IDs
	  FAILEDPCTIDS+=$1

	  #Send E-Mail Reminder
	  #sendanemail "PCT ID $1 failed at stop" #Todo einkommentieren

	else

      #Initiate the start of the PCT after migration
	  STARTAFTERRESTORE=true

	fi

}

################
#Backup Function - Creates a backup of PCT $1 using vzdump if the stopPCT function was successful. If the function cannot create a backup of the PCT correctly, it sends an E-Mail and initiates the skip of the syncAndRestore function.
################
function createBackup {

    #Skip backup if stopPCT failed
	if [ !"$STOPFAILED" ]; then

      yellowMessage "Starting backup for PCT ID $1..."

      #Start Backup and execute postbackup.pl afterwards
      vzdump "$1" --compress gzip --script "$SCRIPTPATH/postbackup.pl" >/dev/null 2>&1

        #Execute if the exit code of the vzdump command isn't 0 (successful)
        if [[ !"$?" -eq 0 ]]; then

          redMessage "Backup for PCT ID $1 failed. Manual intervention required. E-Mail was sent. Continuing with next backup."

		  #Add PCT ID to the array of failed PCT IDs
		  FAILEDPCTIDS+=$1

          #Send E-Mail Reminder
	      #sendanemail "PCT ID $1 failed at backup" #Todo einkommentieren

        fi

	fi

  #Release lock file so the next backup process can start
  releaseLock

}

##############
#Main function - Executes the aquireLock, stopPCT, createBackup and syncAndRestore functions for every PCT ID in the $PCTID array. $1 is the PCT ID, $2 the new IP address and $3 the new PCT ID.
##############
function main {

  #Try to aquire the lock
  aquireLock "$1"

  #Stop the PCT
  stopPCT "$1"

  #Create backup of PCT
  createBackup "$1"

  #Send backup to new host
  syncAndRestore "$1" "$2" "$3"

}

  #Start Message
  echo -ne "\\033[35;1mStarting\033[0m \\033[35;1m[\033[0m\\033[32;1mM\033[0m\\033[35;1m]-igration [\033[0m\\033[32;1mA\033[0m\\033[35;1m]-nd [\033[0m\\033[32;1mR\033[0m\\033[35;1m]-estoration [\033[0m\\033[32;1mS\033[0m\\033[35;1m]-system tool v$INSTALLERVERSION by\033[0m \\033[36;1m@OpusXGmbH\033[0m \\033[35;1m-\033[0m \\033[35;1mwww.opusx.io\033[0m\n"
  sleep 1

  #Run runCleanup function
  runCleanup
  sleep 1

    #Start backup processes for all PCT IDs in pctids.list
    while IFS="" read -r LINE || [ -n "$LINE" ]; do

      #Get PCT ID of line $LINE in pctids.list
      PCTID=$(echo "$LINE" | cut -f1 -d";")

      #Get new IP address of line $LINE in pctids.list
      NEWIP=$(echo "$LINE" | cut -f2 -d";")

	  #Get new PCT ID of line $LINE in pctids.list
	  NEWPCTID=$(echo "$LINE" | cut -f3 -d";")

      #Add PCT ID to array of PCT IDs
	  PCTIDS+=$PCTID

      #Start backup process for every PCT ID
	  main "$PCTID" "$NEWIP" "$NEWPCTID" &
	  sleep 1

    done < pctids.list

  #Wait for all backup processes to finish
  wait

  #Run runCleanup function
  runCleanup

  #Summarize actions
  greenMessage "The script worked on the following PCT IDS: "

    #Show the PCT IDs which the script worked on
    for i in ${PCTIDS[@]}
	do

      echo -ne "\\033[32;1m$i\033[0m "

    done

  echo "\n"

    #Show PCT IDs of PCTs where the mgiration process failed
    if [ FAILEDPCTIDS != "" ]; then

	  redMessage "The installer failed on the following PCT IDS: "

	    for i in ${FAILEDPCTIDS[@]}
		do

          echo -ne "\\033[32;1m${FAILEDPCTIDS[i]}\033[0m,"

        done

	  echo \n

	fi

  greenMessage "Installer will return to the console..."

#Exit with exit code 0
exit 0;
