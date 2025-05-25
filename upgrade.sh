
#!/bin/bash
source ./secrets.env

echo "📦 Backing up the database..."

./SQL-Backup.sh

echo "✅ Successfully backed up the database before Updating Application........"


gcloud compute instance-groups managed set-instance-template dotnet-group --template=dotnet-template --zone=$ZONE 
gcloud compute instance-groups managed rolling-action replace dotnet-group --zone=$ZONE --max-surge 2 



echo "✅ Successfully Updated Burgerpanel Application"