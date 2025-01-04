#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.

# Update the package list
echo "Updating package list..."
sudo apt-get update

# Install necessary packages for Docker installation
echo "Installing necessary packages for Docker..."
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the stable repository
echo "Adding Docker stable repository..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Install Docker
echo "Installing Docker..."
sudo apt install docker.io -y

# Add current user to the Docker group
echo "Adding user to the Docker group..."
sudo usermod -aG docker $USER

# Reload group membership
echo "Reloading group membership..."
newgrp docker

# Install K3D
echo "Installing K3D..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
echo "Installing kubectl..."
curl -sfL https://get.k3s.io | sh -

# Set permissions for k3s.yaml
echo "Setting permissions for k3s.yaml..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Install ArgoCD CLI
echo "Installing ArgoCD CLI..."
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Create a K3D cluster
echo "Creating K3D cluster..."
k3d cluster create -p 443:443 -p 80:30010

# Create the ArgoCD namespace
echo "Creating ArgoCD namespace..."
kubectl create namespace argocd || echo "Namespace argocd may already exist."

# Apply the ArgoCD installation and ingress configuration
echo "Applying ArgoCD installation..."
kubectl apply -n argocd -f ./config/install.yaml
kubectl apply -n argocd -f ./config/ingress.yaml

# Wait for the ArgoCD server to be ready
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=5m

# Retrieve the initial admin password for ArgoCD
echo "Retrieving ArgoCD initial admin password..."
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argocd_password.txt

# Create a development namespace
echo "Creating dev namespace..."
kubectl create namespace dev || echo "Namespace dev may already exist."

# Output the ArgoCD password
echo "ArgoCD password is: $(cat argocd_password.txt)"

# Apply the dev application configuration
echo "Applying dev application configuration..."
kubectl apply -n argocd -f ./config/secret.yaml
kubectl apply -n argocd -f ./config/dev.application.yaml

# List all services
echo "Listing all services..."
kubectl get services --all-namespaces
