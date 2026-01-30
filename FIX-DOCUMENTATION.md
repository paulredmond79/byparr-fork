# Byparr Fork - JSON Response Fix

## Problem Statement

The original byparr implementation returns browser-rendered HTML in the `solution.response` field instead of raw HTTP response bodies. This causes integration issues with applications like Prowlarr that expect raw JSON responses.

### Root Cause

In `src/endpoints.py` (line ~106), the code uses:
```python
response=await dep.page.content()
```

The `page.content()` method returns the **rendered HTML** of the page, which includes browser wrapper tags. For JSON endpoints, Firefox's built-in JSON viewer wraps the JSON in HTML like:
```html
<html>
  <head>
    <link rel="stylesheet" href="resource://content-accessible/plaintext.css">
  </head>
  <body>
    <pre>[{"id":81964344,...}]</pre>
  </body>
</html>
```

This violates FlareSolverr API compatibility where `solution.response` should contain the **raw HTTP response body**.

## The Fix

This fork modifies `src/endpoints.py` to capture the raw HTTP response body using Playwright's `Response.text()` method:

```python
# Capture raw HTTP response body instead of rendered HTML
response_body = ""
if page_request:
    try:
        response_body = await page_request.text()
    except Exception as e:
        logger.warning(f"Failed to get response text, falling back to page content: {e}")
        response_body = await dep.page.content()
else:
    response_body = await dep.page.content()
```

### How It Works

1. **Primary Method**: Uses `page_request.text()` to get the raw HTTP response body
2. **Fallback**: If `text()` fails or `page_request` is None, falls back to `page.content()`
3. **Compatibility**: Maintains backward compatibility while fixing JSON endpoint issues

## Benefits

- ✅ **Prowlarr Compatibility**: JSON responses are now properly parsed
- ✅ **FlareSolverr API Compliance**: Returns raw response bodies as expected
- ✅ **Backward Compatible**: Falls back to page content if needed
- ✅ **All Content Types**: Works for JSON, HTML, XML, and other response types

## Testing

### Test JSON Endpoint (The Pirate Bay)
```bash
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "request.get",
    "url": "https://apibay.org/precompiled/data_top100_recent.json",
    "maxTimeout": 60000
  }'
```

**Expected Result**: `solution.response` contains raw JSON array starting with `[{"id":...}]`, NOT wrapped in HTML tags.

### Test HTML Endpoint
```bash
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "request.get",
    "url": "https://example.com",
    "maxTimeout": 60000
  }'
```

**Expected Result**: `solution.response` contains the actual HTML source of the page.

## Building the Fixed Version

### Using Docker

1. **Build the image**:
```bash
cd byparr-fork
docker build -t byparr-fixed:latest .
```

2. **Run the container**:
```bash
docker run -d \
  --name byparr-fixed \
  -p 8191:8191 \
  -e LOG_LEVEL=DEBUG \
  byparr-fixed:latest
```

### Using Docker Compose

Replace the byparr service in your `docker-compose.yml`:

```yaml
byparr:
  build:
    context: /path/to/byparr-fork
    dockerfile: Dockerfile
  container_name: byparr
  hostname: byparr.internal
  ports:
    - "8191:8191"
  environment:
    LOG_LEVEL: DEBUG
    TZ: UTC
  networks:
    - media-network
  restart: unless-stopped
```

Then rebuild and restart:
```bash
docker-compose up -d --build byparr
```

## Deployment to Hetzner Server

### Option 1: Build on Server
```bash
# SSH to server
ssh root@d.paulredmond.net

# Clone this fork
git clone https://github.com/YOUR_USERNAME/byparr-fork.git /tmp/byparr-fork

# Build image
cd /tmp/byparr-fork
docker build -t byparr-fixed:latest .

# Update docker-compose.yml to use local image
# Change: image: ghcr.io/thephaseless/byparr:latest
# To:     image: byparr-fixed:latest

# Restart stack
cd /path/to/media-stack
docker-compose up -d --force-recreate byparr
```

### Option 2: Push to Private Registry
```bash
# Build locally
docker build -t 78.47.123.83:32768/byparr-fixed:latest .

# Push to private registry (via VPN)
docker push 78.47.123.83:32768/byparr-fixed:latest

# SSH to server and update compose file
ssh root@d.paulredmond.net
# Edit docker-compose.yml to use: 78.47.123.83:32768/byparr-fixed:latest

# Restart stack
docker-compose up -d --force-recreate byparr
```

### Option 3: GitHub Actions CI/CD
Create `.github/workflows/docker-build.yml` to automatically build and push to your private registry on every commit.

## Verifying the Fix

1. **Check byparr logs**:
```bash
docker logs -f byparr
```

2. **Test with Prowlarr**:
   - Configure Prowlarr to use byparr at `http://byparr.internal:8191`
   - Test The Pirate Bay indexer
   - Should see successful searches without "CloudFlare Protection" errors

3. **Check Prowlarr logs**:
```bash
docker logs -f prowlarr
```

Look for successful parsing of JSON responses instead of CloudFlare errors.

## Contributing Back

If you want to contribute this fix back to the original byparr project:

1. Fork the original repository on GitHub
2. Create a new branch: `git checkout -b fix/raw-response-body`
3. Apply these changes
4. Commit with clear message: `fix: Return raw HTTP response body instead of rendered HTML`
5. Push to your fork: `git push origin fix/raw-response-body`
6. Create a Pull Request to `ThePhaseless/Byparr`

## Related Issues

- GitHub Issue #303: "Challenges completed but Prowlarr unable to access"
- Root cause explained in [comment](https://github.com/ThePhaseless/Byparr/issues/303#issuecomment-3818154929)

## License

This fork maintains the same license as the original byparr project. See [LICENSE](LICENSE) file.
