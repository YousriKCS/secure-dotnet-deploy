#!/bin/bash
source ./secrets.env

#locatie instellen
BACKUP_LOCATION="europe-west1"

echo "📦 Starten van Cloud SQL backup voor instance: $DB_INSTANCE..."

# Backup commando
gcloud sql backups create \
  --instance="$DB_INSTANCE" \
  --project="$PROJECT_ID" \
  --location="$BACKUP_LOCATION"

if [ $? -eq 0 ]; then
    echo "✅ Backup succesvol aangemaakt voor $DB_INSTANCE."
else
    echo "❌ Fout bij het maken van de backup."
    exit 1
fi
