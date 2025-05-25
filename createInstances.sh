#!/bin/bash
source ./secrets.env


echo "project id: $PROJECT_ID"
echo "✅ updating permissions on service account"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:dotnet-app@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:dotnet-app@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.networkUser"

# Set up VPC peering for private IP
echo "Setting up VPC network peering..."

# Create a custom VPC network
gcloud compute networks create my-private-network \
    --project=$PROJECT_ID \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

# Create subnet in the VPC
gcloud compute networks subnets create my-private-subnet \
    --project=$PROJECT_ID \
    --network=my-private-network \
    --region=europe-west1 \
    --range=10.0.0.0/24

# Configure private services access
gcloud compute addresses create google-managed-services-range \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --network=my-private-network \
    --project=$PROJECT_ID

# Create VPC peering connection
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-range \
    --network=my-private-network \
    --project=$PROJECT_ID

# Maak een firewallregel aan om toegang tot de DB toe te staan *binnen* het private subnet
gcloud compute firewall-rules create pgconnection \
   --network=my-private-network \
   --direction=INGRESS \
   --priority=1000 \
   --action=ALLOW \
   --rules=tcp:5432 \
   --source-ranges=10.0.0.0/24

gcloud compute firewall-rules create allow-ssh \
  --network=my-private-network \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=ssh-server


echo "✅ VPC network peering and firewall rules set up complete"

# Maak de Redis-instantie aan binnen je custom VPC netwerk
gcloud redis instances create $REDIS \
  --size=1 \
  --region=europe-west1 \
  --tier=BASIC \
  --network=projects/$PROJECT_ID/global/networks/my-private-network

# Maak een firewallregel aan om Redis verkeer binnen het subnet toe te laten
gcloud compute firewall-rules create allow-redis \
  --network=my-private-network \
  --allow=tcp:6379 \
  --source-ranges=10.0.0.0/24 \
  --target-tags=redis-server

# Haal het IP-adres van de Redis-instantie op
Redis_Configuration=$(gcloud redis instances describe $REDIS --region=europe-west1 --format="get(host)")
REDIS_PORT="6379"

# Format Redis connection string met extra parameters
REDIS_CONNECTION="$Redis_Configuration:$REDIS_PORT,connectTimeout=5000,syncTimeout=5000,abortConnect=false"

# Check of Redis connection string geldig is
if [[ -z "$Redis_Configuration" ]]; then
  echo "❌ Redis IP is leeg!"
  exit 1
fi

# Exporteer de Redis connection string
export Redis_Configuration="$REDIS_CONNECTION"

# Debug output
echo "✅ Redis Configuration: $REDIS_CONNECTION"

# Cloud SQL PostgreSQL 16 INSTANCE aanmaken met private IP
echo "Creating Cloud SQL PostgreSQL instance: $DB_INSTANCE"
gcloud sql instances create $DB_INSTANCE \
  --database-version=POSTGRES_16 \
  --cpu=2 \
  --memory=8GB \
  --region=$REGION \
  --edition=ENTERPRISE \
  --network=projects/$PROJECT_ID/global/networks/my-private-network \
  --no-assign-ip  


#  Wachtwoord instellen voor gebruiker
echo "Setting database user password"
gcloud sql users set-password $DB_USER \
  --instance=$DB_INSTANCE \
  --password=$DB_PASSWORD

echo "✅ Database aangemaakt met PRIVATE IP!"

# databank aanmaken
echo "Creating additional database: burgerapp"
gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE

DB_PRIVATE_IP=$(gcloud sql instances describe $DB_INSTANCE --format=json | jq -r '.ipAddresses[] | select(.type=="PRIVATE") | .ipAddress')
echo " Je private IP is: $DB_PRIVATE_IP"

echo "✅ Database-instantie en 'burgerapp' databank aangemaakt!"
# Firewall rule for health checks
gcloud compute firewall-rules create allow-health-check \
    --network=my-private-network \
    --allow=tcp:5000 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=lb-health-check

gcloud compute firewall-rules create allow-http \
    --network=my-private-network \
    --allow=tcp:80 \
    --target-tags=http-server

gcloud compute firewall-rules create allow-https \
    --network=my-private-network \
    --source-ranges=103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,104.16.0.0/12,104.24.0.0/14,108.162.192.0/18 \
    --allow=tcp:443 \
    --target-tags=https-server

# Create SSL certificate
gcloud compute ssl-certificates create dotnet-ssl-cert \
    --domains="$DOMAIN" \
    --global

echo "Creating Instance Template 🔖....."
gcloud compute instance-templates create dotnet-template \
    --project=$PROJECT_ID \
    --machine-type=e2-medium \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --network=my-private-network \
    --subnet=my-private-subnet \
    --region=europe-west1 \
    --metadata-from-file startup-script=startup.sh,secrets=secrets.env \
    --metadata="PentDB_URL=Host=$DB_PRIVATE_IP;Port=$DB_PORT;Database=$DB_NAME;Username=$DB_USER;Password=$DB_PASSWORD,GITLAB_TOKEN=$GITLAB_TOKEN,Redis_Configuration=$REDIS_CONNECTION,RESEND_API_KEY=$RESEND_API_KEY" \
    --tags=ssh-server,lb-health-check,http-server,https-server,redis-server 
# resend api key ophalen
echo $RESEND_API_KEY
echo $OPENAI_API_KEY

echo "✅ Successfully created Instance Template"

echo "Creating Instance Group 📎....."
gcloud compute instance-groups managed create dotnet-group \
    --project=$PROJECT_ID \
    --zone=europe-west1-b \
    --template=dotnet-template \
    --size=2

echo "✅ Successfully created Instance Group"

echo "Setting Named Port 🏷️..."
gcloud compute instance-groups set-named-ports dotnet-group \
    --zone=europe-west1-b \
    --named-ports=http:5000

echo "✅ Successfully set Named Port"

echo "Creating Health Check...."
gcloud beta compute health-checks create tcp dotnet-health-check \
    --port=5000 \
    --proxy-header=NONE \
    --enable-logging \
    --check-interval=60s \
    --timeout=60s \
    --unhealthy-threshold=3 \
    --healthy-threshold=2 \
    --global

echo "✅ Successfully created Health Check"

echo "Setting up Autoscaling and Linking Health Check to Instance Group...."
gcloud compute instance-groups managed update dotnet-group \
    --zone=europe-west1-b \
    --health-check=dotnet-health-check \
    --initial-delay=300s

gcloud compute instance-groups managed set-autoscaling dotnet-group \
    --zone=europe-west1-b \
    --max-num-replicas=3 \
    --min-num-replicas=2 \
    --target-cpu-utilization=0.7 \
    --cool-down-period=1000

echo "✅ Successfully configured Autoscaling and Health Check"

echo "Creating Backend Service with Health Check...."
gcloud compute backend-services create dotnet-backend \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=dotnet-health-check \
    --global

echo "✅ Successfully created Backend Service"

echo "Adding Instance Group to Backend Service...."
gcloud compute backend-services add-backend dotnet-backend \
    --instance-group=dotnet-group \
    --instance-group-zone=europe-west1-b \
    --global \
    --balancing-mode=UTILIZATION

echo "✅ Successfully added Instance Group to Backend Service"

echo "Creating URL Map...."
gcloud compute url-maps create dotnet-url-map \
    --default-service dotnet-backend

echo "✅ Successfully created URL Map"

echo "Creating HTTP Proxy...."
gcloud compute target-http-proxies create dotnet-http-proxy \
    --url-map=dotnet-url-map

echo "✅ Successfully created HTTP Proxy"

echo "Creating HTTPS Proxy...."
gcloud compute target-https-proxies create dotnet-https-proxy \
    --ssl-certificates=dotnet-ssl-cert \
    --url-map=dotnet-url-map

echo "✅ Successfully created HTTPS Proxy"

echo "Creating Global Forwarding Rules...."
gcloud compute forwarding-rules create dotnet-forwarding-rule \
    --global \
    --target-http-proxy=dotnet-http-proxy \
    --ports=80

gcloud compute forwarding-rules create dotnet-https-forwarding-rule \
    --global \
    --target-https-proxy=dotnet-https-proxy \
    --ports=443

# IPv6 proxies aanmaken die de bestaande URL map gebruiken
gcloud compute target-https-proxies create dotnet-https-ipv6-proxy \
  --url-map=dotnet-url-map \
  --ssl-certificates=dotnet-ssl-cert

gcloud compute target-http-proxies create dotnet-http-ipv6-proxy \
  --url-map=dotnet-url-map

# IPv6 adressen aanmaken
gcloud compute addresses create dotnet-ipv6-address \
  --ip-version=IPV6 \
  --global

gcloud compute addresses create dotnet-ipv6-http-address \
  --ip-version=IPV6 \
  --global

# IPv6 forwarding rules aanmaken
gcloud compute forwarding-rules create dotnet-https-ipv6 \
  --global \
  --ip-protocol=TCP \
  --port-range=443 \
  --address=dotnet-ipv6-address \
  --target-https-proxy=dotnet-https-ipv6-proxy

gcloud compute forwarding-rules create dotnet-http-ipv6 \
  --global \
  --ip-protocol=TCP \
  --port-range=80 \
  --address=dotnet-ipv6-http-address \
  --target-http-proxy=dotnet-http-ipv6-proxy


gcloud compute forwarding-rules describe dotnet-https-ipv6 --global --format="get(IPAddress)"

echo "✅ Successfully created Load Balancer with Global IP"

echo "Fetching Load Balancer IP Address...."
gcloud compute forwarding-rules describe dotnet-forwarding-rule \
    --global \
    --format="get(IPAddress)"

gcloud compute forwarding-rules describe dotnet-https-forwarding-rule \
    --global \
    --format="get(IPAddress)"

# 🪣 Bucket aanmaken
echo "🪣 Bucket aanmaken..."
gcloud storage buckets create gs://$BUCKET_NAME \
  --location=europe-west1 \
  --uniform-bucket-level-access

# 📂 Bestand uploaden 
echo "⬆️ Afbeelding uploaden..."
gsutil cp logo.jpg gs://$BUCKET_NAME/

# 🌍 Openbaar maken
gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME



echo "✅ Setup complete!"

gcloud compute firewall-rules list --format="table(name,allowed,targetTags)"
gcloud compute ssl-certificates list
gcloud compute instance-groups managed describe dotnet-group --zone=europe-west1-b
gcloud compute backend-services describe dotnet-backend --global



