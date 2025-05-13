# Hyperswitch GCP One-Click Deploy (Free Tier Focused)

This project provides a Terraform-based solution to deploy Hyperswitch, along with PostgreSQL and Redis, onto a Google Cloud Platform (GCP) f1-micro Compute Engine instance. It's designed with the GCP free tier in mind.

## 🎯 Goal
Create a one-click GCP deployment solution for Hyperswitch, suitable for development/testing environments, aiming to stay within GCP's free-tier limits.

## 🧱 Components
*   **VM**: GCP Compute Engine `f1-micro` instance running Ubuntu 22.04 LTS.
*   **Redis**: Installed as a local process (`redis-server`) on the VM.
*   **Hyperswitch App**: Runs as a Docker container, managed by Docker Compose. Image: `hyperswitch/hyperswitch:latest` (configurable in `startup.sh`).
*   **PostgreSQL Database**: Runs as a Docker container on the same VM, managed by Docker Compose.
*   **Secrets/Configuration**: Managed via an `.env` file created by the `startup.sh` script on the VM. **Review and update default secrets in `startup.sh` before production use.**

## 🚀 Deploy to GCP (Cloud Shell)

[![Deploy to GCP](https://deploy.cloud.run/button.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/manojradhakrishnan/hyperswitch-gcp-deploy&cloudshell_working_dir=hyperswitch-gcp-deploy&cloudshell_tutorial=README.md)

**Note**: Replace `YOUR_USERNAME` in the button URL above with your actual GitHub username after you've forked/cloned and pushed this repository to your own GitHub account.

## Prerequisites

1.  A Google Cloud Platform (GCP) account with billing enabled (required for free tier activation).
2.  `gcloud` CLI installed and authenticated (if running Terraform locally).
3.  Terraform CLI (0.14+) installed (if running Terraform locally).

## ⚙️ Setup Steps (Cloud Shell Recommended)

1.  **Clone the Repository**:
    If not using the "Deploy to GCP" button, clone your repository:
    ```bash
    git clone https://github.com/manojradhakrishnan/hyperswitch-gcp-deploy.git
    cd hyperswitch-gcp-deploy
    ```
    (Replace `YOUR_USERNAME` with your GitHub username)

2.  **Review Configuration (Optional but Recommended)**:
    *   You can modify `variables.tf` to change the default GCP region, zone, or instance name.
    *   **Crucially, review the `/opt/hyperswitch/.env` file content within `startup.sh`**. You will likely want to update placeholder values like `ADMIN_API_KEY` and any other Hyperswitch-specific configurations *before* deploying if this is for more than a quick test.

3.  **Initialize Terraform**:
    This command downloads the necessary provider plugins.
    ```bash
    terraform init
    ```

4.  **Apply Terraform Configuration**:
    This command will provision the GCP resources. You'll be prompted to enter your GCP Project ID.
    ```bash
    terraform apply -var="project_id=your-gcp-project-id"
    ```
    Replace `your-gcp-project-id` with your actual GCP Project ID. Type `yes` when prompted to confirm the changes.

## ✅ Post-Deployment Verification

1.  **Wait for Startup**: Allow a few minutes (5-10 min) for the VM to provision and the `startup.sh` script to complete all installations and configurations. You can monitor the startup script progress by SSHing into the VM and checking `/var/log/startup-script.log`.
2.  **Find VM External IP**:
    *   From the Terraform output: `terraform output instance_ip`
    *   Or via GCP Console: Navigate to Compute Engine > VM instances.
    *   Or via `gcloud`: `gcloud compute instances list --filter="name=hyperswitch-vm" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" --project your-gcp-project-id`
3.  **Access Hyperswitch**: Open your browser and navigate to `http://<VM_EXTERNAL_IP>:8080`.
4.  **SSH into the VM**:
    ```bash
    # Using the Terraform output:
    # terraform output ssh_command 
    # (and run the printed command)
    # Or manually:
    gcloud compute ssh hyperswitch-vm --project your-gcp-project-id --zone <your_vm_zone> 
    ```
    (Replace `your-gcp-project-id` and `<your_vm_zone>` if you changed defaults).
5.  **Verify Redis**:
    Once SSH'd into the VM:
    ```bash
    redis-cli ping
    ```
    Expected output: `PONG`
6.  **Verify Docker Containers**:
    ```bash
    sudo docker ps
    ```
    You should see `hyperswitch_app` and `hyperswitch_postgres` containers running.
7.  **Check Logs**:
    *   Hyperswitch App: `sudo docker logs hyperswitch_app`
    *   PostgreSQL: `sudo docker logs hyperswitch_postgres`
    *   Startup Script: `cat /var/log/startup-script.log`

## 🔄 Updating Hyperswitch

To update the Hyperswitch application to a newer version (assuming the image tag is updated, e.g., `latest` pulls a new version):
1.  SSH into the VM.
2.  Navigate to the Hyperswitch directory: `cd /opt/hyperswitch`
3.  Pull the latest image for the `hyperswitch` service (as defined in `docker-compose.yml`):
    ```bash
    sudo docker compose pull hyperswitch 
    ```
4.  Recreate the Hyperswitch container with the new image:
    ```bash
    sudo docker compose up -d --force-recreate hyperswitch
    ```

## 🧹 Cleanup

To remove all resources created by this Terraform configuration:
```bash
terraform destroy -var="project_id=your-gcp-project-id"
```
Type `yes` when prompted.

## ⚠️ Important Notes on GCP Free Tier

*   The `f1-micro` instance, a small amount of standard persistent disk (up to 30GB, this uses 10GB for boot + Docker volume), and network egress fall under the GCP Free Tier, but limits apply (e.g., one f1-micro instance per account, region-specific).
*   Ensure your account doesn't have other services consuming the free tier allowance for these resources.
*   This setup **avoids Cloud SQL** to minimize the risk of accidental charges, running PostgreSQL in Docker on the VM instead.
*   Always monitor your GCP billing page to understand your usage. 