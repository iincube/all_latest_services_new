#!/bin/bash

GCLOUD="/usr/src/google-cloud-sdk/bin/gcloud"

azure_count=$(wc -l < /usr/local/sbin/listing/azure.csv)
gcp_count=$(wc -l < /usr/local/sbin/listing/gcp.csv)


command_to_run=$(cat <<'EOF'
SERVER_NAME=$(hostname)
if ps -ef | grep -v grep | grep -q "Raptor-Green"; then
    RAPTOR_PATH="/mnt/safetrax/Raptor-Green/RaptorV2/raptor"
elif ps -ef | grep -v grep | grep -q "Raptor-Blue"; then
    RAPTOR_PATH="/mnt/safetrax/Raptor-Blue/RaptorV2/raptor"
else
    RAPTOR_PATH="/mnt/safetrax/RaptorV2/raptor"
fi

if [ -d "$RAPTOR_PATH" ]; then
    
    cd "$RAPTOR_PATH"
        
    RAPTOR_BRANCH=$(sudo git branch | grep '*'; ls -lartdh /mnt/safetrax/RaptorV2 | cut -d ' ' -f6-8)
    RAPTOR_CHECKOUT_DATE=$(git reflog show --date=iso HEAD | grep checkout | head -1 | awk '{print $3, $4}' | xargs -I{} date -d {} +"%b %d %Y %H:%M")   
    Secondcheckout=$(tail -n 20 .git/logs/HEAD | grep checkout) 
    thirdcheckout=$(git log -1 --format="%cd" --date=iso)
    RAPTOR_PARENT=$(dirname "$(dirname "$RAPTOR_PATH")")
    RAPTOR_DATE=$(ls -ld --time-style=+%b\ %d\ %Y "$RAPTOR_PARENT" | awk '{print $6, $7, $8}')
else
    RAPTOR_BRANCH="N/A"
    RAPTOR_DATE="N/A"
fi

SYMLINK=$(sudo ls -larth /mnt/safetrax/serverV2/mongoser | grep "mongoser ->" | awk '{for(i=6;i<=NF;i++) printf $i" "; print ""}')
MONGOSER_PROC=$(ps -ef | grep -v grep | grep mongoser | awk '{print $8}')
ROUTING_JARS=$(ls /mnt/safetrax/serverV2/mongoser/mongoser/lib/ | grep -i routing | tr '\n' ',' | sed 's/,$//')
VRP_PROC=$(ps -ef | grep fat | awk '{for(i=1; i < NF; i++) if($i ~ /fat/) print $i, $(i+1)}' | grep vrpserver | cut -d" " -f1)
CRON_JARS=$(sudo crontab -l | grep -v "^#" | grep -oE "[^/]+\.jar" | tr '\n' ',' | sed 's/,$//')
DATE=$(date "+%b %d %Y")
echo -e " -- $DATE -- \n$RAPTOR_PATH,\n$RAPTOR_BRANCH,$thirdcheckout,\n$SYMLINK\n$ROUTING_JARS,\n$VRP_PROC,\n$CRON_JARS"
EOF
)

output_file=/home/sukomal/check_services/test_check_output.csv
date > $output_file


choice=1
while [[ $choice -le $azure_count ]]
do
    ip=$(awk -F ',' -v choice="$choice" 'NR==choice {print $2}' /usr/local/sbin/listing/azure.csv)
    server_name=$(awk -F ',' -v choice="$choice" 'NR==choice {print $1}' /usr/local/sbin/listing/azure.csv)

    echo -n "$server_name" >> $output_file
    sudo ssh azure-user@$ip "$command_to_run" >> $output_file 
    ((choice++))
done

choice=1

while [[ $choice -le $gcp_count ]]
do
    zone=$(awk -F ',' -v choice="$choice" 'NR==choice {print $2}' /usr/local/sbin/listing/gcp.csv)
    server_name=$(awk -F ',' -v choice="$choice" 'NR==choice {print $1}' /usr/local/sbin/listing/gcp.csv)

    echo -n "$server_name" >> $output_file

#    gcloud compute ssh --zone "asia-south1-c" --ssh-flag="-tt" "abb-hit" --
    $GCLOUD compute --project "academic-elixir-90710" ssh --zone "$zone" "$server_name" --command "$command_to_run" >> $output_file 
    ((choice++))
done

cd "$(dirname "$0")"

git add check_output.csv

git commit -m "Update on $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

git push origin master

