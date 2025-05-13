# Hyperswitch GCP One-Click Deploy (Free Tier Focused) - Deployment Manager Edition

This project provides a Google Cloud Deployment Manager solution to deploy Hyperswitch, along with PostgreSQL and Redis, onto a GCP f1-micro Compute Engine instance. It's designed with the GCP free tier in mind.

## 🎯 Goal
Create a one-click GCP deployment solution for Hyperswitch, suitable for development/testing environments, aiming to stay within GCP's free-tier limits, using Google Cloud Deployment Manager.

## 🧱 Components
*   **VM**: GCP Compute Engine `f1-micro` instance running Ubuntu 22.04 LTS.
*   **Redis**: Installed as a local process (`redis-server`) on the VM via startup script.
*   **Hyperswitch App**: Runs as a Docker container, managed by Docker Compose via startup script. Image: `hyperswitch/hyperswitch:latest`.
*   **PostgreSQL Database**: Runs as a Docker container on the same VM, managed by Docker Compose via startup script.
*   **Secrets/Configuration**: Managed via an `.env` file created by the `startup.sh` content (embedded in `deployment.jinja`) on the VM. **Review and update default secrets in `deployment.jinja` before production use.**

## 📁 Project Files
*   `deployment.jinja`: The main Deployment Manager template (Jinja2 format).
*   `schema.yaml`: Defines input properties for the `deployment.jinja` template.
*   `startup.sh`: (Content is embedded in `deployment.jinja`) Bootstraps Redis, Docker, and Hyperswitch on the VM.
*   `README.md`: This setup guide.

## 🚀 Deploy to GCP (Cloud Shell)

While there isn't a direct one-click button for custom Deployment Manager templates from a Git repo in the same way as Terraform, you can easily deploy using Cloud Shell:

1.  **Open Cloud Shell with this Repository:**
    [![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/manojradhakrishnan/hyperswitch-gcp-deploy&cloudshell_working_dir=hyperswitch-gcp-deploy&cloudshell_git_branch=main&cloudshell_tutorial=README.md)
    (Ensure `manojradhakrishnan` is your GitHub username if you forked, and `main` is your branch)

## Prerequisites

1.  A Google Cloud Platform (GCP) account with billing enabled (required for free tier activation).
2.  The Cloud Deployment Manager API must be enabled for your project. You can enable it by visiting [this link](https://console.cloud.google.com/flows/enableapi?apiid=deploymentmanager.googleapis.com) and selecting your project.

## ⚙️ Setup Steps (In Cloud Shell)

After opening Cloud Shell using the button above, your repository files will be available.

1.  **Navigate to the directory (if not already there)**:
    ```bash
    cd hyperswitch-gcp-deploy
    ```

2.  **Review Configuration (Optional but Recommended)**:
    *   Inspect `deployment.jinja` and `schema.yaml`.
    *   **Crucially, review the `.env` file content within the `startup-script` section of `deployment.jinja`**. You will likely want to update placeholder values like `ADMIN_API_KEY`.

3.  **Deploy using Google Cloud Deployment Manager**:
    You'll need your GCP Project ID.
    ```bash
    # Set your Project ID (replace YOUR_PROJECT_ID)
    gcloud config set project YOUR_PROJECT_ID

    # Create the deployment (you can change 'hyperswitch-deployment' to a name of your choice)
    # It will use default values from schema.yaml unless you provide properties.
    gcloud deployment-manager deployments create hyperswitch-deployment \
        --template deployment.jinja \
        --properties "project_id:YOUR_PROJECT_ID,zone:us-central1-a,deployment_name:hyperswitch-instance"
    ```
    *   Replace `YOUR_PROJECT_ID` with your actual GCP Project ID in both commands.
    *   You can customize `zone` and `deployment_name` properties as needed. If not specified, defaults from `schema.yaml` are used for `zone` and `deployment_name`.

## ✅ Post-Deployment Verification

1.  **Wait for Deployment**: Allow a few minutes (5-10 min) for the resources to be provisioned and the `startup.sh` script to complete.
2.  **Get VM External IP**: Check the outputs of the deployment or find it in the GCP Console.
    ```bash
    gcloud deployment-manager deployments describe hyperswitch-deployment --format="value(outputs.instanceIp)"
    # Or to see all outputs:
    # gcloud deployment-manager manifest describe --deployment hyperswitch-deployment --manifest <MANIFEST_NAME_FROM_DESCRIBE_DEPLOYMENT>
    # The manifest name is usually the deployment name plus a timestamp, e.g., hyperswitch-deployment-1234567890.yaml
    # Simpler: go to GCP Console -> Deployment Manager -> select your deployment -> View Details/Outputs
    # Or: GCP Console -> Compute Engine -> VM Instances page to find the IP of 'hyperswitch-instance-vm' (or similar name).
    ```
    The `outputs` section in `deployment.jinja` defines `instanceIp`.

3.  **Access Hyperswitch**: Open your browser and navigate to `http://<VM_EXTERNAL_IP>:8080`.
4.  **SSH into the VM**: Use the `sshCommand` output from the deployment or `gcloud`:
    ```bash
    # From deployment output (if available and correctly formatted)
    # gcloud deployment-manager deployments describe hyperswitch-deployment --format="value(outputs.sshCommand)" | bash

    # Or manually (replace YOUR_PROJECT_ID and ZONE and VM_NAME as needed):
    # The VM name will be like 'hyperswitch-instance-vm' based on default deployment_name
    gcloud compute ssh $(gcloud deployment-manager deployments describe hyperswitch-deployment --format="value(outputs.instanceName)") --project YOUR_PROJECT_ID --zone <ZONE_FROM_PROPERTIES_OR_SCHEMA>
    ```

5.  **Verify Services on VM** (once SSH'd):
    *   Redis: `redis-cli ping` (Expected: `PONG`)
    *   Docker: `sudo docker ps` (See `hyperswitch_app`, `hyperswitch_postgres`)
    *   Logs: `/var/log/startup-script.log`, `sudo docker logs hyperswitch_app`, `sudo docker logs hyperswitch_postgres`

## 🔄 Updating the Deployment

If you change `deployment.jinja` or `schema.yaml`:
```bash
gcloud deployment-manager deployments update hyperswitch-deployment \
    --template deployment.jinja \
    --properties "project_id:YOUR_PROJECT_ID,zone:us-central1-a,deployment_name:hyperswitch-instance"
```

## 🧹 Cleanup

To delete all resources created by this deployment:
```bash
gcloud deployment-manager deployments delete hyperswitch-deployment
```
(Type `y` when prompted).

## ⚠️ Important Notes on GCP Free Tier

*   The `f1-micro` instance, a small amount of standard persistent disk (10GB), and network egress fall under the GCP Free Tier, but limits apply.
*   Ensure your account doesn't have other services consuming the free tier allowance.
*   This setup **avoids Cloud SQL** to minimize the risk of accidental charges, running PostgreSQL in Docker on the VM.
*   Always monitor your GCP billing page. 