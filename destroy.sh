#!/bin/bash
source ./secrets.env

echo "🚨 Start met verwijderen van ALLE resources..."

# Forwarding Rules
gcloud compute forwarding-rules delete dotnet-forwarding-rule --global --quiet 
gcloud compute forwarding-rules delete dotnet-https-forwarding-rule --global --quiet 

echo "🧨 Destroying IPv6 forwarding rules..."
gcloud compute forwarding-rules delete dotnet-https-ipv6 --global --quiet
gcloud compute forwarding-rules delete dotnet-http-ipv6 --global --quiet

echo "🧨 Destroying IPv6 addresses..."
gcloud compute addresses delete dotnet-ipv6-address --global --quiet
gcloud compute addresses delete dotnet-ipv6-http-address --global --quiet

echo "✅ IPv6 resources destroyed successfully!"

# Target Proxies
gcloud compute target-http-proxies delete dotnet-http-proxy --quiet 
gcloud compute target-https-proxies delete dotnet-https-proxy --quiet 

gcloud compute target-https-proxies delete dotnet-https-ipv6-proxy --quiet
gcloud compute target-http-proxies delete dotnet-http-ipv6-proxy --quiet

# URL Map
gcloud compute url-maps delete dotnet-url-map --quiet 

# Backend Service
gcloud compute backend-services delete dotnet-backend --global --quiet 

# Instance Group
gcloud compute instance-groups managed delete dotnet-group --zone=europe-west1-b --quiet

# Instance Template
gcloud compute instance-templates delete dotnet-template --quiet 

# Health Check
gcloud compute health-checks delete dotnet-health-check --global --quiet 

# SSL Certificaat
gcloud compute ssl-certificates delete dotnet-ssl-cert --quiet 

# Firewall Rules
gcloud compute firewall-rules delete allow-health-check --quiet 
gcloud compute firewall-rules delete allow-http --quiet
gcloud compute firewall-rules delete allow-https --quiet
gcloud compute firewall-rules delete pgconnection --quiet
gcloud compute firewall-rules delete allow-redis --quiet
gcloud compute firewall-rules delete allow-ssh --quiet


# Bucket + inhoud
echo "🪣 Verwijderen van bucket '$BUCKET_NAME' en inhoud..."
gsutil -m rm -r "gs://$BUCKET_NAME" || {
  echo "⚠️ Bucket verwijderen mislukt of bestaat niet."
}
echo "✅ Bucket verwijderd."

# Cloud SQL
echo "🧨 Verwijderen van Cloud SQL instance: $DB_INSTANCE"
gcloud sql instances delete $DB_INSTANCE --quiet
echo "✅ Cloud SQL instance verwijderd!"

# Redis
echo "🧨 Verwijderen van Redis instance: $REDIS"
gcloud redis instances delete $REDIS --region=europe-west1 --quiet

echo "✅ Redis instance verwijderd."

# VPC IP range
gcloud compute addresses delete google-managed-services-range \
    --global \
    --quiet 

# Subnet en netwerk
gcloud compute networks subnets delete my-private-subnet \
    --region=europe-west1 \
    --quiet 

# VPC netwerk
gcloud compute networks delete my-private-network --quiet 

echo "✅ ✅ ALLE RESOURCES ZIJN VERWIJDERD!"
