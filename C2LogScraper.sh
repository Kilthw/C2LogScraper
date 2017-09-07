#!/bin/bash
if [[ $# == 0 ]] ; then
   	echo "
[!] Need to supply path to cobaltstrike backup directory.
    
Example: ./C2LogScraper.sh ~/share/Working/CS_Backups

This script works best if run against full cobaltstrike folder backups and requires that the exported TSVs be somewhere under the supplied cobaltstrike backup directory.

Note: This script currently doesn't like spaces in folder/file names.
    " | fold -sw 80
    exit 1
fi
logs=${1%/}
#Create CSV
echo '"NCATS C2 LOG"' > C2Report.csv

createdFiles(){
	#Created/Uploaded Files
	echo "" >> C2Report.csv
	echo "" >> C2Report.csv
	echo '"CREATED/UPLOADED FILES"' >> C2Report.csv
	echo 'CREATED/UPLOADED FILES'
	echo '"IP Address"','"Created/Uploaded File"','"Log Line"' >> C2Report.csv
	printf "%-15s %-20s %-40s %-70s %s\n" "IP Address" "Host Name" "Created/Uploaded File" "Log Line"
	divider=$(printf "%-145s" "-")
	echo "${divider// /-}"
	#Bloudhound Files
	grep -ri "invoke-bloodhound" $logs | grep -i 'Tasked beacon to run' | while read -r a; do
		ip=$(echo "$a" | cut -d":" -f1 | rev | cut -d"/" -f2 | rev)
		sid=$(echo "$a" | cut -d":" -f1 | rev | cut -d"_" -f1 | rev | cut -d"." -f1)
		cn=$(grep -ri "$sid" $logs | grep "sessions.tsv" | cut -d"	" -f6 | sort -u)
		logLine=$(echo "$a" | cut -d":" -f2-)
		logFile=$(echo "$a" | cut -d":" -f1)
		fileLoc=$(grep -iF "$logLine" $logFile -B10 -A10 | grep 'Writing output to CSVs in' | cut -d" " -f6)
		#remove carriage return
		fileLoc=${fileLoc//[$'\r\n']}
		la=false
		gm=false
		us=false
		t=false
		lower=$(echo "$a" | tr '[:upper:]' '[:lower:]')
		if [[ $lower == *"collectionmethod trusts"* ]]; then
			t=true
		fi
		if [[ $lower == *"collectionmethod session"* ]]; then
			us=true
		fi
		if [[ $lower == *"collectionmethod group"* ]]; then
			gm=true
		fi
		if [[ $lower == *"collectionmethod localgroup"* ]]; then
			gm=true
		fi
		if [[ $lower == *"collectionmethod gpolocalgroup"* ]]; then
			gm=true
		fi
		if [[ $lower == *"collectionmethod computeronly"* ]]; then
			us=true
			la=true
		fi
		if [[ $lower == *"collectionmethod loggedon"* ]]; then
			us=true
		fi
		if [[ $lower == *"domaincontroller"* ]]; then
			la=true
			gm=true
		fi
		if [[ "$la" = false ]] && [[ "$gm" = false ]] && [[ "$us" = false ]] && [[ "$t" = false ]]; then
			la=true
			gm=true
			us=true
			t=true
		fi
		if [[ "$la" = true ]]; then
			printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" $fileLoc'local_admins.csv' "$logLine"
			echo "$ip",\""$cn"\",\"$fileLoc'local_admins.csv'\",\""$logLine"\" >> C2Report.csv
		fi
		if [[ "$us" = true ]]; then
			printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" $fileLoc'user_sessions.csv' "$logLine"
			echo "$ip",\""$cn"\",\"$fileLoc'user_sessions.csv'\",\""$logLine"\" >> C2Report.csv
		fi
		if [[ "$gm" = true ]]; then
			printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" $fileLoc'group_memberships.csv' "$logLine"
			echo "$ip",\""$cn"\",\"$fileLoc'group_memberships.csv'\",\""$logLine"\" >> C2Report.csv
		fi
		if [[ "$t" = true ]]; then
			printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" $fileLoc'trusts.csv' "$logLine"
			echo "$ip",\""$cn"\",\"$fileLoc'trusts.csv'\",\""$logLine"\" >> C2Report.csv
		fi		
	done
	#Created files through output redirection
	grep -ri "\[input\]" $logs | grep -P "(>.*>)" | grep -vi 'nul' | while read -r a; do
		ip=$(echo "$a" | cut -d":" -f1 | rev | cut -d"/" -f2 | rev)
		sid=$(echo "$a" | cut -d":" -f1 | rev | cut -d"_" -f1 | rev | cut -d"." -f1)
		cn=$(grep -ri "$sid" $logs | grep "sessions.tsv" | cut -d"	" -f6 | sort -u)
		logLine=$(echo "$a" | cut -d":" -f2-)
		fileLoc=$(echo "$a" | cut -d">" -f3-)
		fileLoc=${fileLoc/ /}
		fileLoc=${fileLoc/>/}
		backLoc=$fileLoc
		lower=$(echo $fileLoc | tr '[:upper:]' '[:lower:]')
		if [[ $lower != *'c:\'* ]]; then
			pathLog=$(grep -ri "$fileLoc" $logs -B20 -A20 | grep -i "$fileLoc" | grep -iF 'C:\')
			fullLoc=($(echo $pathLog | grep -oP "(?<=C:).*(?=$file)"))
			fileLoc='C:'$fullLoc
		fi
		if [[ $fileLoc != *"$backLoc"* ]]; then
			fileLoc=$backLoc
		fi
		printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" "$fileLoc" "$logLine"
		echo "$ip",\""$cn"\",\""$fileLoc"\",\""$logLine"\" >> C2Report.csv
	done
	#Uploaded files
	grep -ri 'Tasked beacon to upload' $logs | while read -r a; do
		ip=$(echo "$a" | cut -d":" -f1 | rev | cut -d"/" -f2 | rev)
		sid=$(echo "$a" | cut -d":" -f1 | rev | cut -d"_" -f1 | rev | cut -d"." -f1)
		cn=$(grep -ri "$sid" $logs | grep "sessions.tsv" | cut -d"	" -f6 | sort -u)
		logLine=$(echo "$a" | cut -d":" -f2-)
		fileLoc=$(echo "$a" | cut -d":" -f2- | cut -d" " -f10-)
		backLoc=$fileLoc
		lower=$(echo $fileLoc | tr '[:upper:]' '[:lower:]')
		if [[ $lower != *'c:\'* ]]; then
			pathLog=$(grep -ri "$fileLoc" $logs -B20 -A20 | grep -i "$fileLoc" | grep -iF 'C:\')
			fullLoc=($(echo $pathLog | grep -oP "(?<=C:).*(?=$file)"))
			fileLoc='C:'$fullLoc
		fi
		if [[ $fileLoc != *"$backLoc"* ]]; then
			fileLoc=$backLoc
		fi
		printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" "$fileLoc" "$logLine"
		echo "$ip",\""$cn"\",\""$fileLoc"\",\""$logLine"\" >> C2Report.csv
	done
}

deletedFiles(){
	#Deleted Files
	echo ''
	echo ''
	echo '' >> C2Report.csv
	echo '' >> C2Report.csv
	echo '"DELETED FILES"' >> C2Report.csv
	echo '"IP Address"','"Deleted File"','"Log Line"' >> C2Report.csv
	echo 'DELETED FILES'
	printf "%-15s %-20s %-40s %-70s %s\n" "IP Address" "Host Name" "Deleted File" "Log Line"
	divider=$(printf "%-145s" "-")
	echo "${divider// /-}"
	grep -ri "tasked beacon" $logs | grep -i "remove\|del\ " | grep -vP "([rR]emove.*[pP]ersist)" | while read -r a; do 
		ip=$(echo "$a" | cut -d":" -f1 | rev | cut -d"/" -f2 | rev)
		sid=$(echo "$a" | cut -d":" -f1 | rev | cut -d"_" -f1 | rev | cut -d"." -f1)
		cn=$(grep -ri "$sid" $logs | grep "sessions.tsv" | cut -d"	" -f6 | sort -u)
		lower=$(echo "$a" | tr '[:upper:]' '[:lower:]')
		if [[ $lower != *"del"* ]]; then
			fileLoc=$(echo "$a" | cut -d":" -f2- | cut -d" " -f8-)
		else
			fileLoc=$(echo "$a" | cut -d":" -f2- | cut -d" " -f9-)
		fi
		backLoc=$fileLoc
		logLine=$(echo "$a" | cut -d":" -f2-)
		lower=$(echo $fileLoc | tr '[:upper:]' '[:lower:]')
		if [[ $lower != *'c:\'* ]]; then
			pathLog=$(grep -ri "$fileLoc" $logs -B20 -A20 | grep -i "$fileLoc" | grep -iF 'C:\')
			fullLoc=($(echo $pathLog | grep -oP "(?<=C:).*(?=$file)"))
			fileLoc='C:'$fullLoc
		fi
		if [[ $fileLoc != *"$backLoc"* ]]; then
			fileLoc=$backLoc
		fi
		#remove carriage return
		fileLoc=${fileLoc//[$'\r\n']}
		logLine=${logLine//[$'\r\n']}
		printf "%-15s %-20s %-40s %-70s %s\n" $ip "$cn" "$fileLoc" "$logLine"
		echo "$ip",\""$cn"\",\""$fileLoc"\",\""$logLine"\" >> C2Report.csv
	done
}

persistenceLog(){
	#Persistence Log
	echo ''
	echo ''
	echo '' >> C2Report.csv
	echo '' >> C2Report.csv
	echo '"PERSISTENCE LOG"' >> C2Report.csv
	echo '"Date/Time"','"IP Address"','"Log Line"' >> C2Report.csv
	echo 'PERSISTENCE LOG'
	printf "%-15s %-15s %-20s %-70s %s\n" "Date/Time" "IP Address" "Host Name" "Log Line"
	divider=$(printf "%-109s" "-")
	echo "${divider// /-}"
	grep -ri "persist" $logs | grep -v "persistent=" | grep -v ".tsv\|\[input\]\|\[error\]\|.xml\|Tasked beacon to \|CsPersistentChatAdministrator\|powershell-import\|Install-\|Remove-\|releasenotes.txt\|downloads\|Persistent Routes:\|Binary file\| note " | while read -r a; do
		ip=$(echo "$a" | cut -d":" -f1 | rev | cut -d"/" -f2 | rev)
		sid=$(echo "$a" | cut -d":" -f1 | rev | cut -d"_" -f1 | rev | cut -d"." -f1)
		cn=$(grep -ri "$sid" $logs | grep "sessions.tsv" | cut -d"	" -f6 | sort -u)
		logLine=$(echo "$a" | cut -d":" -f2-)
		lower=$(echo $logLine | tr '[:upper:]' '[:lower:]')
		#if [[ $lower == *'registry'* ]]; then
		#	regUninstall=true
		#fi
		#remove carriage return
		logLine=${logLine//[$'\r\n']}
		logFile=$(echo "$a" | cut -d":" -f1)
		beaconCmd=$(grep -iF "$logLine" $logFile -B10 | grep -P "(> [pP]ower.*[pP]ersist)" | grep -vi 'import')
		dateTime=$(echo "$beaconCmd" | cut -d" " -f1-2)
		printf "%-15s %-15s %-20s %-70s %s\n" "$dateTime" "$ip" "$cn" "$logLine"
		echo \""$dateTime"\","$ip",\""$cn"\",\""$logLine"\" >> C2Report.csv
	done

	#echo $regUninstall
	#if [[ "$regUninstall" = true ]]; then
	echo "Adding RegPersistence Uninstall Instructions to C2Report.csv"
	echo "" >> C2Report.csv
	echo "" >> C2Report.csv
	echo "\# For those machines that the NCATS team was unable to remove RegPersistence:" >> C2Report.csv
	echo "\# Execute the following PowerShell commands to remove the stored script and the registry autorun key." >> C2Report.csv
	echo "Remove-ItemProperty -Force -Path HKCU:Software\Microsoft\Windows -Name Debug;" >> C2Report.csv
	echo "Remove-ItemProperty -Force -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Run\ -Name Debug;" >> C2Report.csv
	#fi
}

credentialsLog(){
	#compromised Credentials Log
	echo ''
	echo ''
	echo '' >> C2Report.csv
	echo '' >> C2Report.csv
	echo '"COMPROMISED CREDENTIALS LOG"' >> C2Report.csv
	echo '"User"','"Realm"','"Host"' >> C2Report.csv
	echo 'COMPROMISED CREDENTIALS LOG'
	printf "%-40s %-70s %-20s %s\n" "User" "Realm" "Host"
	divider=$(printf "%-130s" "-")
	echo "${divider// /-}"
	grep -r "user	password	realm	source	host	note" $logs | while read -r a; do
		logFile=$(echo "$a" | cut -d":" -f1)
		cat $logFile | grep -v "user	password	realm	source	host	note" | cut -d"	" -f1,3,5 | sort -u | while read -r b; do
			uid=$(echo "$b" | cut -d"	" -f1)
			realm=$(echo "$b" | cut -d"	" -f2)
			host=$(echo "$b" | cut -d"	" -f3)
			printf "%-40s %-70s %-20s %s\n" "$uid" "$realm" "$host"
			echo \""$uid"\","$realm",\""$host"\" >> C2Report.csv
		done
	done
}

beaconLog(){
	#Beacon Log
	echo ''
	echo ''
	echo '' >> C2Report.csv
	echo '' >> C2Report.csv
	echo '"BEACON LOG"' >> C2Report.csv
	echo '"Date/Time"','"IP Address"','"Host Name"','"User Name"' >> C2Report.csv
	echo 'BEACON LOG'
	printf "%-15s %-15s %-20s %-20s %s\n" "Date/Time" "IP Address" "Host Name" "User Name"
	divider=$(printf "%-70s" "-")
	echo "${divider// /-}"
	grep -Ri metadata $logs | grep -i computer | grep -i user | grep -v "BASEWINDOWS7AVM\|rvauser" | grep -i version | cut -f 2- -d ':' | tr ';' ',' | cut -f 1,2,6,8,10 -d ' ' | sed s/' '/', '/2 | sed s/', '/','/g | while read -r a; do
		dt=$(echo "$a" | cut -d"," -f1)
		ip=$(echo "$a" | cut -d"," -f2)
		host=$(echo "$a" | cut -d"," -f3)
		uid=$(echo "$a" | cut -d"," -f4)
		printf "%-15s %-15s %-20s %-20s %s\n" "$dt" "$ip" "$host" "$uid"
		echo \""$dt"\","$ip",\""$host"\",\""$uid"\" >> C2Report.csv
	done
}

createdFiles
deletedFiles
persistenceLog
credentialsLog
beaconLog
