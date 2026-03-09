#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install git
apt-get install -y git

# Clone repository and setup backend
# This will be replaced by deployment script
echo "Backend VM initialized"
