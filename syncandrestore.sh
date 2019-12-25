#!/bin/bash

###############
#Main Variables (do not change)
###############
INSTALLERVERSION="1.0.0"

##############
#PCT variables
##############
NEWPCTID=$2
DUMPDIR=$3
TARFILE=$4
STARTAFTERRESTORE=$5
NEWIP=$1
SUBNET="/32"
GATEWAY="$(echo $NEWIP | rev | cut -d"." -f2- | rev).1"
UPLINK="38"
FIREWALL="0"
STORAGE="local-lvm"
SWAP="1024"
NESTING="1"
ONBOOT="1"
FURTHEROPTIONS="-unprivileged -ignore-unpack-errors"

###############
#Mail Variables
###############
MAILSENDER="email@email.de"
MAILRECIEVER="email@email.de"
MAILMESSAGE="Bitte den Titel beachten."

#################
#Access variables
#################
SSHIP="1.1.1.1"
SSHUSER="root"

##################
#Further variables
##################
# Activate Nesting, Activate automatic start at host boot, set storage, set swap, set new networking, Activate automatic start after restoration, convert to unprivileged PCT, ignore unpack errors
RESTOREOPTIONS="-features nesting=$NESTING -onboot=$ONBOOT -storage=$STORAGE -swap=$SWAP -net0 name=eth0,bridge=vmbr0,firewall=$FIREWALL,gw=$GATEWAY,ip=$NEWIP$SUBNET,rate=$UPLINK $FURTHEROPTIONS"

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

##############
#actionChecker function - executes $3 and sends an E-Mail every 5 minutes when it fails
##############
function actionChecker {

    eval "$3"
    #Stop if $3 failed
    if [[ !"$?" -eq 0 ]]; then

      redMessage "$2 for PCT ID $1 failed. Manual intervention required. An E-Mail was sent. Command: $3\nOutput: $(cat /tmp/latestcommand)"
      #Send E-Mail Reminder
	  #sendanemail "PCT ID $1 failed at $2" #Todo einkommentieren

    fi

}

##############
#Mail Function - Sends a mail from $MAILSENDER to $MAILRECIEVER with the title "Migration notice: $1" (as where $1 is the first parameter of the function call) and the message $MAILMESSAGE
##############
function sendanemail {

  sendemail -f "$MAILSENDER" -t "$MAILRECIEVER" -u "Migration notice: $1" -m "$MAILMESSAGE" -v -o message-charset=utf-8 >/dev/null 2>&1

}

##############
#Sync Function - synchronizes the backup to the new host. Parameters on actionChecker call: 1: Type of action 2. PCT ID 3. Command
##############
function syncBackup {

  yellowMessage "Syncing backup of PCT $NEWPCTID to new host..."
  actionChecker "$NEWPCTID" "Sync" "sftp $SSHUSER@$SSHIP:$DUMPDIR <<< $'put $TARFILE' >/tmp/latestcommand 2>&1"

}

function restoreBackup {

  yellowMessage "Starting restoration of PCT $NEWPCTID on new host..."
  actionChecker "$NEWPCTID" "Restore" "ssh $SSHUSER@$SSHIP \"pct restore $NEWPCTID $TARFILE $RESTOREOPTIONS\" >/tmp/latestcommand 2>&1"
  #sendanemail "PCT ID $NEWPCTID successfully migrated!" #Todo: Einkommentieren

}

function startIfStartedBefore {

  if $STARTAFTERRESTORE; then
  actionChecker "$NEWPCTID" "Start" "ssh $SSHUSER@$SSHIP \"pct start $NEWPCTID \" >/tmp/latestcommand 2>&1"
  fi

}

##############
#Main function - Executes the stopPCT and createBackup function for every PCT ID in the $pctid array
##############
function main {

  syncBackup
  restoreBackup
  startIfStartedBefore

}

main

exit 0;