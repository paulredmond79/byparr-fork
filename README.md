# Byparr Fork - Raw Response Body Fix 🔧

> **⚠️ FORKED VERSION** - This is a modified version of [ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr) with a critical fix for JSON endpoint compatibility. See [original README](README.original.md) for upstream documentation.

---

## 🐛 Why This Fork Exists

The original byparr returns **browser-rendered HTML** in the `solution.response` field instead of **raw HTTP response bodies**. This breaks integration with applications like Prowlarr that expect raw JSON responses.

### The Problem

**Original byparr response for JSON endpoint:**
```json
{
  "solution": {
    "response": "<html><body><pre>[{\"id\":81964344,...}]</pre></body></html>"
  }
}
```

**Expected response (FlareSolverr compatible):**
```json
{
  "solution": {
    "response": "[{\"id\":81964344,...}]"
  }
}
```

## ✅ The Fix

Modified [src/endpoints.py](src/endpoints.py) to capture raw HTTP response body using Playwright's `Response.text()` method instead of `page.content()`.

**Key Changes:**
- Uses `page_request.text()` to get raw HTTP response body
- Falls back to `page.content()` if needed (backward compatible)
- Maintains FlareSolverr API compatibility

**See [FIX-DOCUMENTATION.md](FIX-DOCUMENTATION.md) for detailed explanation.**

---

## 📋 Quick Start

### 1. Clone This Repository
```bash
git clone https://github.com/YOUR_USERNAME/byparr-fork.git
cd byparr-fork
```

### 2. Build Docker Image
```bash
docker build -t byparr-fixed:latest .
```

### 3. Run Container
```bash
docker run -d \
  --name byparr-fixed \
  -p 8191:8191 \
  -e LOG_LEVEL=DEBUG \
  byparr-fixed:latest
```

### 4. Test the Fix
```bash
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "request.get",
    "url": "https://apibay.org/precompiled/data_top100_recent.json",
    "maxTimeout": 60000
  }'
```

You should now see **raw JSON** in `solution.response`, not HTML-wrapped JSON! ✨

---

## 🚀 Deployment Scripts

### PowerShell (Windows)
```powershell
.\deploy.ps1                 # Build on server
.\deploy.ps1 -BuildLocal     # Build locally and push to registry
```

### Bash (Linux/Mac)
```bash
chmod +x deploy.sh
./deploy.sh                  # Follow prompts
```

### Manual Deployment

**Update your docker-compose.yml:**
```yaml
byparr:
  # image: ghcr.io/thephaseless/byparr:latest  # OLD
  image: YOUR_REGISTRY/byparr-fixed:latest      # NEW
  # ... rest of config unchanged
```

**Rebuild and restart:**
```bash
docker-compose up -d --force-recreate byparr
```

---

## 🧪 Testing with Prowlarr

1. Configure Prowlarr to use byparr at `http://byparr.internal:8191`
2. Test The Pirate Bay indexer (or any CloudFlare-protected indexer)
3. ✅ Verify successful searches without "CloudFlare Protection" errors

**Check logs:**
```bash
docker logs -f byparr
docker logs -f prowlarr
```

---

## 📖 Documentation

| File | Description |
|------|-------------|
| **[FIX-DOCUMENTATION.md](FIX-DOCUMENTATION.md)** | Detailed problem analysis, fix explanation, testing guide |
| **[deploy.ps1](deploy.ps1)** | PowerShell deployment script for Windows |
| **[deploy.sh](deploy.sh)** | Bash deployment script for Linux/Mac |
| **[README.original.md](README.original.md)** | Original byparr README (renamed) |

---

## 🔗 Related Issues

- **Original Issue:** [ThePhaseless/Byparr#303](https://github.com/ThePhaseless/Byparr/issues/303)
- **Root Cause Analysis:** [Issue Comment](https://github.com/ThePhaseless/Byparr/issues/303#issuecomment-3818154929)

---

## 🤝 Contributing Back to Original Project

Want to help get this fix merged upstream?

1. Fork [ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)
2. Create branch: `git checkout -b fix/raw-response-body`
3. Apply changes from [src/endpoints.py](src/endpoints.py)
4. Create Pull Request referencing issue #303

---

## 📄 License

This fork maintains the same license as the original byparr project.

---

## 🙏 Credits

- **Original Project:** [ThePhaseless/Byparr](https://github.com/ThePhaseless/Byparr)
- **Fix Developed By:** @paulredmond79
- **Issue Reported By:** Multiple users (see issue #303)

---

**⚠️ Important:** This is a temporary fork until the fix is merged into the original byparr project. Consider switching back to the official image once the fix is released upstream.

---

For original byparr documentation, see [README.original.md](README.original.md).
