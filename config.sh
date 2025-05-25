#!/bin/bash
source ./secrets.env

# Inloggen met Google Cloud via browser
gcloud auth login

# Maak een geldige project-ID
PROJECT_ID="pentacoders-$(date +%Y%m%d%H%M%S)"

# Maak het project aan
gcloud projects create $PROJECT_ID

# Zet het nieuwe project in de configuratie
gcloud config set project $PROJECT_ID

# Koppel het factureringsaccount
BILLING_ACCOUNT_ID="01FF1E-EBCBE7-B8A6A9"
gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT_ID

# Maak een service account aan met 
SERVICE_ACCOUNT_NAME="dotnet-app"
SERVICE_ACCOUNT_DISPLAY_NAME="Dotnet Application Service Account"
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name "$SERVICE_ACCOUNT_DISPLAY_NAME" \
    --project $PROJECT_ID

# Wacht even om zeker te zijn dat de serviceaccount correct is aangemaakt
sleep 10

# Ken dezelfde rollen toe aan de service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.networkUser"

# Ken ook editor rol toe voor algemene toegang
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor"

# Maak een key voor het service account
KEY_FILE_PATH="$SERVICE_ACCOUNT_NAME-key.json"
gcloud iam service-accounts keys create $KEY_FILE_PATH \
    --iam-account "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --project $PROJECT_ID

echo "✅ Service account $SERVICE_ACCOUNT_NAME is aangemaakt met key: $KEY_FILE_PATH"

# Save PROJECT_ID to secrets.env and export it
sed -i '' '/^PROJECT_ID=/d' secrets.env
echo "PROJECT_ID=$PROJECT_ID" >> secrets.env
export PROJECT_ID="$PROJECT_ID"

# Verify the PROJECT_ID is set
echo "Project ID ingesteld als: $PROJECT_ID"

gcloud projects list

# Enable required APIs
echo "🔌 Enabling required Google Cloud APIs..."

# Redis API
gcloud services enable redis.googleapis.com

# Cloud SQL
gcloud services enable sqladmin.googleapis.com

# Compute Engine
gcloud services enable compute.googleapis.com

# Cloud Storage
gcloud services enable storage.googleapis.com
gcloud services enable storage-api.googleapis.com

# Service Networking (for private connections)
gcloud services enable servicenetworking.googleapis.com

# Resource Manager
gcloud services enable cloudresourcemanager.googleapis.com

echo "✅ All required APIs have been enabled."
