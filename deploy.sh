#!/bin/bash
# Quick deployment script for byparr-fixed to Hetzner server

set -e

SERVER="root@d.paulredmond.net"
REGISTRY="78.47.123.83:32768"
IMAGE_NAME="byparr-fixed"
VERSION="latest"

echo "=========================================="
echo "Byparr Fix Deployment Script"
echo "=========================================="
echo ""

# Check if we should build locally or on server
read -p "Build locally and push to registry? (y/n, default: n): " BUILD_LOCAL
BUILD_LOCAL=${BUILD_LOCAL:-n}

if [[ "$BUILD_LOCAL" == "y" ]]; then
    echo ""
    echo "Step 1: Building Docker image locally..."
    docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} .
    
    echo ""
    echo "Step 2: Pushing to private registry..."
    echo "Note: Ensure you're connected via VPN to access registry at ${REGISTRY}"
    docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    
    echo ""
    echo "Step 3: Updating docker-compose.yml on server..."
    ssh ${SERVER} "sed -i 's|image: ghcr.io/thephaseless/byparr:latest|image: ${REGISTRY}/${IMAGE_NAME}:${VERSION}|g' /home/paul/media-stack/docker-compose.yml"
else
    echo ""
    echo "Step 1: Copying files to server..."
    ssh ${SERVER} "mkdir -p /tmp/byparr-fork"
    scp -r ./* ${SERVER}:/tmp/byparr-fork/
    
    echo ""
    echo "Step 2: Building Docker image on server..."
    ssh ${SERVER} "cd /tmp/byparr-fork && docker build -t ${IMAGE_NAME}:${VERSION} ."
    
    echo ""
    echo "Step 3: Updating docker-compose.yml on server..."
    ssh ${SERVER} "sed -i 's|image: ghcr.io/thephaseless/byparr:latest|image: ${IMAGE_NAME}:${VERSION}|g' /home/paul/media-stack/docker-compose.yml"
fi

echo ""
echo "Step 4: Restarting byparr container..."
ssh ${SERVER} "cd /home/paul/media-stack && docker-compose up -d --force-recreate byparr"

echo ""
echo "Step 5: Checking container status..."
ssh ${SERVER} "docker ps | grep byparr"

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check logs: ssh ${SERVER} 'docker logs -f byparr'"
echo "2. Test with curl (see FIX-DOCUMENTATION.md)"
echo "3. Test with Prowlarr indexer"
echo ""
