#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Python
apt-get install -y python3 python3-pip python3-venv

# Install git
apt-get install -y git

# Clone repository and setup frontend
# This will be replaced by deployment script
echo "Frontend VM initialized"
