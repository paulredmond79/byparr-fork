# Quick Deployment Script for Windows PowerShell
# Deploys byparr-fixed to Hetzner server

param(
    [switch]$BuildLocal = $false,
    [string]$Server = "root@d.paulredmond.net",
    [string]$Registry = "78.47.123.83:32768",
    [string]$ImageName = "byparr-fixed",
    [string]$Version = "latest"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Byparr Fix Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($BuildLocal) {
    Write-Host "Step 1: Building Docker image locally..." -ForegroundColor Yellow
    docker build -t "${Registry}/${ImageName}:${Version}" .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Step 2: Pushing to private registry..." -ForegroundColor Yellow
    Write-Host "Note: Ensure you're connected via VPN to access registry at ${Registry}" -ForegroundColor Gray
    docker push "${Registry}/${ImageName}:${Version}"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed! Are you connected via VPN?" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Step 3: Updating docker-compose.yml on server..." -ForegroundColor Yellow
    ssh $Server "sed -i 's|image: ghcr.io/thephaseless/byparr:latest|image: ${Registry}/${ImageName}:${Version}|g' /home/paul/media-stack/docker-compose.yml"
} else {
    Write-Host "Step 1: Copying files to server..." -ForegroundColor Yellow
    ssh $Server "mkdir -p /tmp/byparr-fork"
    scp -r * "${Server}:/tmp/byparr-fork/"
    
    Write-Host ""
    Write-Host "Step 2: Building Docker image on server..." -ForegroundColor Yellow
    ssh $Server "cd /tmp/byparr-fork && docker build -t ${ImageName}:${Version} ."
    
    Write-Host ""
    Write-Host "Step 3: Updating docker-compose.yml on server..." -ForegroundColor Yellow
    ssh $Server "sed -i 's|image: ghcr.io/thephaseless/byparr:latest|image: ${ImageName}:${Version}|g' /home/paul/media-stack/docker-compose.yml"
}

Write-Host ""
Write-Host "Step 4: Restarting byparr container..." -ForegroundColor Yellow
ssh $Server "cd /home/paul/media-stack && docker-compose up -d --force-recreate byparr"

Write-Host ""
Write-Host "Step 5: Checking container status..." -ForegroundColor Yellow
ssh $Server "docker ps | grep byparr"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Check logs: ssh $Server 'docker logs -f byparr'" -ForegroundColor Gray
Write-Host "2. Test with curl (see FIX-DOCUMENTATION.md)" -ForegroundColor Gray
Write-Host "3. Test with Prowlarr indexer" -ForegroundColor Gray
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host "  .\deploy.ps1                 # Build on server" -ForegroundColor Gray
Write-Host "  .\deploy.ps1 -BuildLocal     # Build locally and push to registry" -ForegroundColor Gray
Write-Host ""
