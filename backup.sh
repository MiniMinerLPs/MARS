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

function errorQuit {
  errorExit 'Exit now!'
}

function errorExit {
  redMessage "${@}"
  exit 1
}

function errorContinue {
  redMessage "Invalid option."
  return
}

function runCleanup {

  rm "$SCRIPTPATH/pctid.lock" >/dev/null 2>&1
  rm -rf $SCRIPTPATH/VMIDS >/dev/null 2>&1

}

##############
#Mail Function - Sends a mail from $MAILSENDER to $MAILRECIEVER with the title "Migration notice: $1" (as where $1 is the first parameter of the function call) and the message $MAILMESSAGE
##############
function sendanemail {

  sendemail -f "$MAILSENDER" -t "$MAILRECIEVER" -u "Migration notice: $1" -m "$MAILMESSAGE" -v -o message-charset=utf-8 >/dev/null 2>&1

}

function aquireLock {

  yellowMessage "Aquiring lock for backup process of PCT ID $1"

    while :
	do
	    if [ -f "$SCRIPTPATH/pctid.lock" ]; then
          sleep 2
		else

		  break

        fi
	done
	
  echo "$1" > pctid.lock
  greenMessage "Lock for backup process of PCT ID $1 aquired!"

}

function releaseLock {

  rm "$SCRIPTPATH/pctid.lock"
  echo -ne "\n"

}

function syncAndRestore {

    if [[ ! " ${FAILEDPCTIDS[@]} " =~ " $1 " ]]; then

        if [ -f "$SCRIPTPATH/VMIDS/$1" ]; then

          DUMPDIR=$(cat "$SCRIPTPATH/VMIDS/$1" | cut -d ";" -f2)
          TARFILE=$(cat "$SCRIPTPATH/VMIDS/$1" | cut -d ";" -f3)
          bash $SCRIPTPATH/syncandrestore.sh $2 $3 $DUMPDIR $TARFILE $STARTAFTERRESTORE

	    else

	      redMessage "Syncfile missing. (Probably because the backup task failed)"

	    fi

	fi

}

##################
#PCT Stop Function - Stops the PCT $1. If the function cannot stop the PCT correctly, it sends E-Mail reminders every 5 minutes
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
	  STOPFAILED=true
	  FAILEDPCTIDS+=$1
	  #Send E-Mail Reminder
	  #sendanemail "PCT ID $1 failed at stop" #Todo einkommentieren

	else

	  STARTAFTERRESTORE=true

	fi

}

################
#Backup Function - Creates a backup of PCT $1 using vzdump. If the function cannot create a backup of the PCT correctly, it sends E-Mail reminders every 5 minutes.
################
function createBackup {

	if [ !"$STOPFAILED" ]; then

      yellowMessage "Starting backup for PCT ID $1..."

      #Start Backup
      vzdump "$1" --compress gzip --script "$SCRIPTPATH/postbackup.pl" >/dev/null 2>&1

        #Stop if Backup failed
        if [[ !"$?" -eq 0 ]]; then

          redMessage "Backup for PCT ID $1 failed. Manual intervention required. E-Mail was sent. Continuing with next backup."
		  FAILEDPCTIDS+=$1
          #Send E-Mail Reminder
	      #sendanemail "PCT ID $1 failed at backup" #Todo einkommentieren

        fi

	fi

  releaseLock

}

##############
#Main function - Executes the stopPCT and createBackup function for every PCT ID in the $pctid array
##############
function main {

    aquireLock "$1"
    stopPCT "$1"
    createBackup "$1"
	syncAndRestore "$1" "$2" "$3"

}

  echo -ne "\\033[35;1mStarting\033[0m \\033[35;1m[\033[0m\\033[32;1mM\033[0m\\033[35;1m]-igration [\033[0m\\033[32;1mA\033[0m\\033[35;1m]-nd [\033[0m\\033[32;1mR\033[0m\\033[35;1m]-estoration [\033[0m\\033[32;1mS\033[0m\\033[35;1m]-system tool v$INSTALLERVERSION by\033[0m \\033[36;1m@OpusXGmbH\033[0m \\033[35;1m-\033[0m \\033[35;1mwww.opusx.io\033[0m\n"
  sleep 1
  runCleanup
  sleep 1

    while IFS="" read -r line || [ -n "$line" ]; do

      PCTID=$(echo "$line" | cut -f1 -d";")
      NEWIP=$(echo "$line" | cut -f2 -d";")
	  NEWPCTID=$(echo "$line" | cut -f3 -d";")
	  PCTIDS+=$PCTID

	  main "$PCTID" "$NEWIP" "$NEWPCTID" &
	  sleep 1

    done < pctids.list

  wait
  runCleanup
  greenMessage "The script worked on the following PCT IDS: "

    for i in ${PCTIDS[@]}
	do

      echo -ne "\\033[32;1m$i\033[0m "

    done

  echo "\n"

    if [ FAILEDPCTIDS != "" ]; then

	  redMessage "The installer failed on the following PCT IDS: "

	    for i in ${FAILEDPCTIDS[@]}
		do

          echo -ne "\\033[32;1m${FAILEDPCTIDS[i]}\033[0m,"

        done

	  echo \n

	fi

  greenMessage "Installer will return to the console..."

exit 0;
