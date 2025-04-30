# Python Web Application on GKE with CI/CD and Secure Bastion Access

## Overview

This project demonstrates the deployment of a simple Python (Flask) web application to Google Kubernetes Engine (GKE). It includes a Continuous Integration (CI) pipeline using Google Cloud Build, which automatically builds a Docker image and pushes it to Google Artifact Registry upon code changes pushed to GitHub. Deployment to GKE is then performed manually from a secure bastion host accessed via Identity-Aware Proxy (IAP).

This project was undertaken as a learning exercise to understand:
-   Containerizing a Python web application with Docker.
-   Setting up and configuring GKE with a private control plane endpoint and private nodes.
-   Implementing a CI pipeline with Cloud Build and Artifact Registry.
-   Securely accessing and managing a GKE cluster from a bastion host using IAP, especially in an environment with restrictive organization policies (e.g., preventing VMs from having external IPs, requiring Shielded VMs).
-   The fundamentals of Kubernetes deployments and services.

## Technologies Used

* **Python:** For the web application (using Flask framework).
* **Docker:** For containerizing the application.
* **Google Kubernetes Engine (GKE):**
    * Private Cluster (private nodes and private control plane endpoint).
    * Shielded Nodes.
* **Google Artifact Registry:** For storing Docker container images.
* **Google Cloud Build:** For Continuous Integration (automating image builds and pushes).
* **Google Compute Engine (GCE):** For the bastion host VM (accessed via IAP).
* **Google Identity-Aware Proxy (IAP):** For secure SSH access to the bastion host.
* **Google Cloud VPC Network & Cloud NAT:** For network configuration.
* **Git & GitHub:** For version control and triggering CI builds.
* **kubectl:** For interacting with the GKE cluster.
* **gcloud CLI:** For managing Google Cloud resources.

## Project Workflow

1.  **Local Development:** Make changes to the Python Flask application code.
2.  **Git Push:** Commit and push changes to a GitHub repository.
3.  **Cloud Build CI Trigger:** A Cloud Build trigger (connected to the GitHub repo) automatically starts a build.
4.  **Cloud Build Pipeline (`cloudbuild.yaml`):**
    * Builds the Docker image from the `Dockerfile`.
    * Tags the image with `:latest` and the commit `$SHORT_SHA`.
    * Pushes the tagged images to Google Artifact Registry.
5.  **Manual Deployment from Bastion Host:**
    * SSH into a private GCE VM (bastion host) using IAP.
    * Use `kubectl` (configured for the GKE cluster's private endpoint) to manually trigger a rollout of the new image to the GKE deployment.
6.  **Access Application:** The updated application is accessible via an external LoadBalancer.

## Prerequisites

* Google Cloud Platform (GCP) account with billing enabled.
* `gcloud` CLI installed and authenticated locally (for initial setup).
* Git installed locally.
* A GitHub account.
* (Optional) Docker Desktop installed locally for testing the Docker image locally before pushing.

## Setup and Deployment Steps Overview

This project involves several setup stages:

### 1. Local Application & Dockerization
* A simple Python Flask web application is defined in `app/main.py` and `app/requirements.txt`.
* A `Dockerfile` is used to containerize this application.

### 2. Google Cloud Infrastructure Setup
* **VPC Network (`my-gke-network`):** A custom VPC network was created.
* **Cloud NAT:** Configured for `my-gke-network` to allow private GKE nodes and the private bastion host to access the internet for necessary outbound connections (e.g., pulling base images, `apt-get update`).
* **Artifact Registry Repository (`my-app-repo`):** A Docker repository created in Artifact Registry (e.g., in `us-central1`) to store the application images.
* **GKE Cluster (`my-gke-cluster`):**
    * Created as a private cluster (`--enable-private-nodes`, `--enable-private-endpoint`).
    * Uses Shielded Nodes (`--enable-shielded-nodes`, `--shielded-secure-boot`, etc.).
    * Configured to use `my-gke-network`.
* **Bastion Host GCE VM (`bastion-host-private`):**
    * A small GCE VM (e.g., `e2-micro`) created *without an external IP address*.
    * Runs a standard Linux distribution (e.g., Debian 11).
    * Configured with Shielded VM features.
    * Placed within `my-gke-network`.
* **Firewall Rule for IAP:** A firewall rule (`allow-iap-ssh`) was created to allow SSH traffic from IAP's IP range (`35.235.240.0/20`) to VMs tagged with `iap-ssh-allow`.
* **IAM Permissions for IAP:** The user account needs the `roles/iap.tunnelResourceAccessor` role to SSH into the bastion via IAP.

### 3. CI Pipeline (Cloud Build)
* **`cloudbuild.yaml`:** Defines the build steps:
    1.  Builds the Docker image using the `Dockerfile`.
    2.  Tags the image with `:latest` and `:$SHORT_SHA`.
    3.  Pushes both tagged images to the Artifact Registry repository (`us-central1-docker.pkg.dev/YOUR_GCP_PROJECT_ID/my-app-repo/my-python-app`).
    * Logging is set to `CLOUD_LOGGING_ONLY`.
* **Cloud Build Trigger:** Configured to start a build when code is pushed to the `main` branch of the connected GitHub repository.
* **Service Account Permissions:** The service account used by Cloud Build (in this project, it ended up being the Compute Engine default service account `YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com`) was granted necessary roles:
    * `roles/storage.objectViewer` (to read source from GCS)
    * `roles/logging.logWriter` (to write logs to Cloud Logging)
    * `roles/artifactregistry.writer` (to push images to Artifact Registry)
    * *(Note: For automated GKE deployment, it would also need GKE permissions like `roles/container.developer`)*

### 4. Kubernetes Manifests & Manual Deployment
* **`deployment.yaml`:** Defines the Kubernetes Deployment for the application, specifying:
    * Number of replicas.
    * Pod template with labels.
    * Container specification, pointing to the image in Artifact Registry (e.g., `us-central1-docker.pkg.dev/YOUR_GCP_PROJECT_ID/my-app-repo/my-python-app:latest`).
    * Container port and resource requests/limits.
* **`service.yaml`:** Defines the Kubernetes Service of `type: LoadBalancer` to expose the application externally.
* **Deployment Process from Bastion Host:**
    1.  SSH into `bastion-host-private` using `gcloud compute ssh ... --tunnel-through-iap`.
    2.  Install `kubectl`, `git`, and configure `gcloud` on the bastion.
    3.  Run `gcloud container clusters get-credentials my-gke-cluster --zone <your-zone> --project YOUR_GCP_PROJECT_ID --internal-ip` to configure `kubectl` for the private GKE endpoint.
    4.  Clone the GitHub repository to the bastion host to access `deployment.yaml` and `service.yaml`.
    5.  Apply the manifests:
        ```bash
        kubectl apply -f deployment.yaml
        kubectl apply -f service.yaml
        ```

## How to Use / Test

1.  **Prerequisites & Setup:** Ensure all the GCP infrastructure (VPC, NAT, GKE private cluster, Artifact Registry, Bastion Host with IAP, firewall rules, IAM for IAP) is set up as described above. Ensure `cloudbuild.yaml`, `Dockerfile`, `deployment.yaml`, `service.yaml`, and application code are in your GitHub repository. Set up the Cloud Build trigger.
2.  **Make a Code Change:** Modify the Python application code in `app/main.py` locally.
3.  **Push to GitHub:**
    ```bash
    git add .
    git commit -m "Your change description"
    git push origin main
    ```
4.  **Monitor Cloud Build:** Observe the build trigger automatically in the Google Cloud Console under "Cloud Build" > "History". Wait for it to complete successfully (building and pushing the new image to Artifact Registry).
5.  **Manually Deploy to GKE from Bastion Host:**
    * SSH into your bastion host (`bastion-host-private`) using IAP:
        ```bash
        gcloud compute ssh bastion-host-private --zone <your-vm-zone> --project YOUR_GCP_PROJECT_ID --tunnel-through-iap
        ```
    * Once on the bastion, trigger a rolling update of your GKE deployment:
        ```bash
        kubectl rollout restart deployment my-python-app-deployment --namespace default
        ```
        (Ensure `my-python-app-deployment` matches your deployment's name).
    * Monitor the rollout:
        ```bash
        kubectl rollout status deployment/my-python-app-deployment
        kubectl get pods -l app=my-python-app -w
        ```
6.  **Access the Application:**
    * Get the external IP of your service (if you don't have it already):
        ```bash
        # Run this from the bastion host
        kubectl get service my-python-app-service --namespace default
        ```
    * Open `http://<EXTERNAL_IP>` in your browser to see the updated application.

## Key Learnings (Example)
* Navigating Google Cloud organization policies (e.g., `vmExternalIpAccess`, `requireShieldedVm`) and adapting infrastructure deployment accordingly.
* Setting up secure access to a private GKE cluster using a bastion host with IAP.
* Understanding the permissions required for different service accounts involved in a CI/CD pipeline (Cloud Build SA, Compute Engine default SA).
* The difference between implicit and explicit image pushes in Cloud Build when coordinating with deployment steps.

## Future Enhancements (Example)
* Fully automate the CD (Continuous Deployment) step to GKE using Cloud Deploy or by adding `kubectl apply` steps directly in Cloud Build (with careful consideration of using unique image tags like `$SHORT_SHA` in `deployment.yaml`).
* Implement Helm for packaging Kubernetes applications.
* Add more sophisticated health checks and probes to the Kubernetes deployment.
* Integrate monitoring and logging more deeply.

---

Replace `YOUR_GCP_PROJECT_ID`, `YOUR_PROJECT_NUMBER`, `YOUR_USERNAME/YOUR_REPOSITORY_NAME`, `<your-zone>`, and `<your-vm-zone>` with your specific values. You might also want to adjust the names (`my-gke-network`, `my-app-repo`, `my-gke-cluster`, `bastion-host-private`, `my-python-app-deployment`) if you used different ones, though the ones in the README are consistent with what we discussed.