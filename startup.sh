#!/bin/bash

exec > /var/log/startup-script.log 2>&1
# Update & Installaties
sudo apt update
# Installeer .NET 8.0
if ! dotnet --list-sdks | grep -q "8.0"; then
    echo "⚠️ .NET 8.0 niet gevonden. Installeren..."
    sudo apt install -y dotnet-sdk-8.0
else
    echo "✅ .NET 8.0 is al geïnstalleerd!"
fi
# Installeer Node.js 
if ! node -v | grep -q "v18"; then
    echo "⚠️ Node.js 18 niet gevonden. Installeren..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo "✅ Node.js 18 is al geïnstalleerd!"
fi

# Installeer Git
if ! git --version &>/dev/null; then
    echo "⚠️ Git niet gevonden. Installeren..."
    sudo apt install -y git
else
    echo "✅ Git is al geïnstalleerd!"
fi

# Installeer PostgreSQL client
if ! psql --version &>/dev/null; then
    echo "⚠️ PostgreSQL client niet gevonden. Installeren..."
    sudo apt-get install -y postgresql-client
else
    echo "✅ PostgreSQL client is al geïnstalleerd!"
fi


export HOME=/home/yousri_khalfallah
export DOTNET_CLI_HOME=$HOME
# Clone de GitLab repo
ENV_FILE="/etc/environmentvariables.conf"
URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
GITLAB_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "$URL/GITLAB_TOKEN")
GIT_REPO="https://gitlab+deploy-token-8061419:${GITLAB_TOKEN}@gitlab.com/kdg-ti/integratieproject-1/202425/2_pentacode/development.git"

mkdir -p /root/app
git clone "$GIT_REPO" /root/app/source

# ⚙️ Build Vite frontend
cd /root/app/source/Burgerpanel/UI-MVC/ClientApp
rm -rf node_modules package-lock.json dist
npm install
npm install vite --save-dev
npm run build

# 🛠️ .NET restore
cd /root/app/source/Burgerpanel/UI-MVC
dotnet nuget list source
dotnet restore
dotnet build --configuration Release

# 📦 Environment Variables
PentDB_URL=$(curl -s -H "Metadata-Flavor: Google" "$URL/PentDB_URL")
echo "PentDB_URL=$PentDB_URL" > "$ENV_FILE"
Redis_Configuration=$(curl -s -H "Metadata-Flavor: Google" "$URL/Redis_Configuration")
echo "Redis_Configuration=$Redis_Configuration" >> "$ENV_FILE"
RESEND_API_KEY=$(curl -s -H "Metadata-Flavor: Google" "$URL/RESEND_API_KEY")
echo "RESEND_API_KEY=$RESEND_API_KEY" >> "$ENV_FILE"

# 🛠️ .NET publish
dotnet publish -c Release -o /root/app/published 


# Maak het systemd service-bestand aan
export ASPNETCORE_ENVIRONMENT=Production
cat <<EOF > /etc/systemd/system/pentacoders.service
[Unit]
Description=Burgerpanel
After=network.target

[Service]
WorkingDirectory=/root/app/published
ExecStart=/usr/bin/dotnet /root/app/published/Burgerpanel.UI.MVC.dll
Restart=always
User=root
EnvironmentFile=/etc/environmentvariables.conf
Environment=ASPNETCORE_URLS=http://0.0.0.0:5000

[Install]
WantedBy=multi-user.target
EOF

# Laad de systemd-service opnieuw
systemctl daemon-reload
systemctl enable pentacoders.service
systemctl start pentacoders.service

