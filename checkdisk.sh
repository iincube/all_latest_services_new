#!/bin/bash

source /etc/profile
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

GCLOUD="/usr/src/google-cloud-sdk/bin/gcloud"
AZURE_CSV="/usr/local/sbin/listing/azure.csv"
GCP_CSV="/usr/local/sbin/listing/gcp.csv"
OUTPUT_FILE="/home/sukomal/check_services/checkdisk.csv"
REPO_DIR="$(dirname "$0")"
MAIL_TO="rajesh.v@mtap.in selvapriya.s@mtap.in vishnu.velayudhan@mtap.in sukomal.das@mtap.in rohan.paunikar@mtap.in tharun.gandhe@mtap.in"
read -a MAIL_RECIPIENTS <<< "$MAIL_TO"


echo "ServerName,DiskUsage_MNT,DiskUsage_Root" > "$OUTPUT_FILE"

# GCP LOOP (working part)
gcp_count=$(wc -l < "$GCP_CSV")
for ((i=1; i<=gcp_count; i++)); do
    zone=$(awk -F ',' -v line="$i" 'NR==line {print $2}' "$GCP_CSV")
    server_name=$(awk -F ',' -v line="$i" 'NR==line {print $1}' "$GCP_CSV")

    echo -n "$server_name," >> "$OUTPUT_FILE"
    $GCLOUD compute ssh --zone "$zone" "$server_name" --command 'bash -c '"'"'echo -n "$(df -h /mnt/safetrax | awk "NR==2 {print \$5}" | tr -d %),"; df -h / | awk "NR==2 {print \$5}" | tr -d %'"'"'' >> "$OUTPUT_FILE"
done

# AZURE LOOP (try/catch style)
azure_count=$(wc -l < "$AZURE_CSV")
for ((i=1; i<=azure_count; i++)); do
    ip=$(awk -F ',' -v line="$i" 'NR==line {print $2}' "$AZURE_CSV")
    server_name=$(awk -F ',' -v line="$i" 'NR==line {print $1}' "$AZURE_CSV")

    echo -n "$server_name," >> "$OUTPUT_FILE"
    sudo ssh -o StrictHostKeyChecking=no azure-user@$ip 'sudo bash -c '"'"'echo -n "$(df -h /mnt/safetrax | awk "NR==2 {print \$5}" | tr -d %),"; df -h / | awk "NR==2 {print \$5}" | tr -d %'"'"'' >> "$OUTPUT_FILE" 2>> /tmp/azure_errors.log
done

# GIT COMMIT
cd "$REPO_DIR"
git add "$OUTPUT_FILE"
git commit -m "Disk usage update: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
git push origin master

# Mail
ALERT_BODY=""
while IFS=',' read -r server mnt root; do
    [[ "$server" == "ServerName" ]] && continue
    [[ -z "$mnt" || -z "$root" ]] && continue

    # Only numbers allowed for mnt/root, avoid junk lines
    if [[ "$mnt" =~ ^[0-9]+$ ]] && (( mnt >= 75 )); then
        ALERT_BODY+="$server has /mnt/safetrax at ${mnt}%\n"
    fi

    if [[ "$root" =~ ^[0-9]+$ ]] && (( root >= 75 )); then
        ALERT_BODY+="$server has / at ${root}%\n"
    fi
done < "$OUTPUT_FILE"

# Send Mail if Alerts Exist
if [[ -n "$ALERT_BODY" ]]; then
    sudo echo -e "$ALERT_BODY" | mailx -v -s "Disk Usage Alert - $(date '+%Y-%m-%d %H:%M:%S')" "${MAIL_RECIPIENTS[@]}"
fi
                                                         
