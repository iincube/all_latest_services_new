#!/bin/bash

GCLOUD="/usr/src/google-cloud-sdk/bin/gcloud"

azure_count=$(wc -l < /usr/local/sbin/listing/azure.csv)
gcp_count=$(wc -l < /usr/local/sbin/listing/gcp.csv)

command_to_run="echo \"\$( sudo df -h /mnt/safetrax | grep -E 'T|G' | awk '{print \$5}' | sed 's/%//'),\$( sudo df -h / | grep -E 'T|G' | awk '{print \$5}' | sed 's/%//'); echo '--- Full df output ---'; sudo df -h\""

output_file=/home/sukomal/check_output.csv
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


    $GCLOUD compute --project "academic-elixir-90710" ssh --zone "$zone" "$server_name" --command "$command_to_run" >> $output_file 
    ((choice++))
done

cd "$(dirname "$0")"

git add check_output.csv

git commit -m "Update on $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

git push origin master

