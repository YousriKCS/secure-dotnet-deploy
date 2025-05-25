# Secure .NET Web App Deployment on Google Cloud Platform

This repository contains all of the scripts, configuration templates and documentation you need to deploy, update and teardown a production-grade .NET web application on Google Cloud Platform (GCP).  It was built as a PoC for automated, secure, zero-downtime deployments with cloud-native infrastructure and Cloudflare integration.

---

## 🔑 Requirements

Before you begin, make sure you have:

- **Google Cloud account**  
  – Active Billing Account and permissions to create projects, service accounts, enable APIs  
- **.NET application code**  
  – Your web app source (e.g. in GitLab or a local folder)  
- **Google Cloud SDK**  
  – Installed & authenticated on your workstation (`gcloud init`)  
- **Cloudflare account** (optional, for DNS & WAF)  
  – API token / Global API key with DNS edit permissions  

---

## 🛠️ Configuration

1. **`secrets.env`**  
   Stores your GCP project defaults and database credentials.  
   ```dotenv
   # GCP
   PROJECT_ID=my-gcp-project
   REGION=us-central1
   ZONE=us-central1-a

   # Database
   DB_NAME=appdb
   DB_USER=appuser
   DB_PASS=S3cur3P@ss!

   # GitLab
   GITLAB_TOKEN=glpat-xxxx

   # Domain & Ports
   DOMAIN=example.com
   HTTP_PORT=80
   HTTPS_PORT=443

   # Auto-scaling
   MIN_REPLICAS=1
   MAX_REPLICAS=3
   TARGET_CPU=0.6
   ```
2. **`cloudflare.env`**  
   Contains your Cloudflare API settings for DNS updates and proxy.  
   ```dotenv
   CF_API_TOKEN=ckey_xxxx
   CF_ZONE_ID=abcd1234
   CF_ROOT_RECORD=mydomain.com
   CF_WWW_RECORD=www.mydomain.com
   ```

---

## 📋 Scripts & Workflow

| Script                    | Purpose                                                                                              |
|---------------------------|------------------------------------------------------------------------------------------------------|
| `01_config.sh`            | ● Creates GCP project & service account, links billing, and enables all required APIs               |
| `02_createInstances.sh`   | ● Provisions VPC, subnet, MIG with auto-scaling, Cloud SQL, load balancer, firewall rules, etc.     |
| `03_startup.sh`            | ● Installs .NET runtime, clones your repo, configures environment, starts the app as a systemd service |
| `04_CFUpdate.sh`          | ● Updates Cloudflare DNS A/AAAA records to point at your Load Balancer IP                           |
| `05_CFProxy.sh`           | ● Enables Cloudflare proxy (WAF + CDN) once your GCP SSL certificate is ACTIVE                      |
| `06_upgrade.sh`           | ● Performs zero-downtime rolling update and takes a pre-update Cloud SQL backup                      |
| `07_SQL-Backup.sh`         | ● Triggers on-demand dump of your Cloud SQL database for off-site archive                            |
| `08_destroy.sh`           | ● Tears down all provisioned GCP resources in the correct order                                      |
| `09_destroyProject.sh`    | ● Deletes the entire GCP project for a clean slate                                                   |

---

## 🚀 Getting Started

1. **Populate your `.env` files**  
   ```bash
   cp secrets.env.example secrets.env
   cp cloudflare.env.example cloudflare.env
   ```
   Edit `secrets.env` and `cloudflare.env` with your own values.
2. **Make all scripts executable**  
   ```bash
   chmod +x *.sh
   ```
3. **Run each script in sequence**  
   ```bash
   ./01_config.sh
   ./02_createInstances.sh => activates Startup.sh
   ./03_CFUpdate.sh
   ./04_CFProxy.sh
   ```
4. **To update your app**  
   ```bash
   ./05_upgrade.sh
   ```
5. **To Backup your Database**
   ```bash
   ./06_SQL-Backup.sh
   ```
6. **To clean up**  
   ```bash
   ./07_destroy.sh
   ./08_destroyProject.sh
   ```

---

## 📂 Repository Structure

```
.
├── 01_config.sh
├── 02_createInstances.sh
├── 03_startup.sh
├── 04_CFUpdate.sh
├── 05_CFProxy.sh
├── 06_upgrade.sh
├── 07_SQL-Backup.sh
├── 08_destroy.sh
├── 09_destroyProject.sh
├── secrets.env.example
├── cloudflare.env.example
└── README.md
```

---


