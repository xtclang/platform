# Platform Internals

This document contains technical details about the internal workings of the Ecstasy PaaS platform.

## DNS Configuration

### Non-Standard DNS Setup

The `xqiz.it` PAAS uses a **non-standard DNS setup** where `*.localhost.xqiz.it` is configured in public DNS to resolve to `127.0.0.1`:

```bash
# DNS Record (configured at xqiz.it's nameservers: ns81/ns82.domaincontrol.com)
*.localhost.xqiz.it.  600  IN  A  127.0.0.1
```

### How It Works

- Any subdomain under `localhost.xqiz.it` (like `xtc-platform.localhost.xqiz.it`) resolves to your local machine
- This is **publicly visible DNS** pointing to localhost, which is highly unusual
- The main `xqiz.it` domain points to real public IPs (AWS), but the `localhost` subdomain wildcard points to loopback

### Why This Is Non-Standard

- Most DNS rebind protection will block this (browsers/routers preventing public DNS from returning private IPs)
- Creates potential security concerns (public domain cookies/auth on localhost)
- Goes against typical DNS best practices of not mixing public DNS with localhost resolution

### Tradeoffs

**Pros:**
- Allows clean URLs without `/etc/hosts` editing or local DNS server
- Simplifies local development with realistic domain names

**Cons:**
- DNS rebind protection may block it on some networks/routers
- Security implications of public domain credentials on local services

### DNS Rebind Protection Workarounds

If resolution fails, your DNS server likely has rebind protection. For example, on Verizon routers:
1. Go to Advanced → Network Settings → DNS Server
2. Add an exception for "127.0.0.1" in "Exceptions to DNS Rebind Protection"

### Testing DNS Resolution

```bash
ping xtc-platform.localhost.xqiz.it  # Should return 127.0.0.1
```

**Alternative approach:** Use `localhost:8090` directly instead of the DNS-based URL.

## Port Configuration

### Default Ports

The platform defaults to:
- **HTTP**: 8080
- **HTTPS**: 8090

These ports don't require special privileges and work on all operating systems.

### Configuring Custom Ports

**Before first build** (optional):
Set in `$GRADLE_USER_HOME/gradle.properties`:
```properties
platform.httpPort=3000
platform.httpsPort=3443
```
These values will be embedded in the kernel module and used when `~/xqiz.it/platform/cfg.json` is created on first run.

**After first run:**
Edit `~/xqiz.it/platform/cfg.json` and restart the platform.

**Via command line** (temporary):
```bash
./gradlew build -Pplatform.httpPort=3000 -Pplatform.httpsPort=3443
```

### Using Privileged Ports 80/443 (macOS)

If you want to use standard HTTP/HTTPS ports (80/443) on macOS, you'll need to set up port forwarding since these are privileged ports:

1. Create a file `~/xqiz.it/platform/port-forwarding.conf`:
   ```
   rdr pass on lo0 inet proto tcp from any to self port 80  -> 127.0.0.1 port 8080
   rdr pass on lo0 inet proto tcp from any to self port 443 -> 127.0.0.1 port 8090
   ```

2. Enable port forwarding (requires sudo):
   ```bash
   sudo pfctl -evf ~/xqiz.it/platform/port-forwarding.conf
   ```

3. **Note**: This needs to be re-run after each OS reboot.

**Alternative**: Use a container runtime (Docker/Podman) which handles port mapping without requiring privileged access.

## Configuration Files

### cfg.json

The networking part of the PAAS is configured with a JSON formatted file named **cfg.json**.

**Location:** `~/xqiz.it/platform/cfg.json`

**Behavior:**
- If `cfg.json` already exists, it will be loaded and processed
- If not present, it will be created from the default template at [kernel/src/main/resources/cfg.json](../kernel/src/main/resources/cfg.json)
- Ports configured in Gradle properties are embedded during first run
- Manual edits to `cfg.json` require platform restart to take effect

## Password and Key Storage

The password you choose during the very first run will be used to encrypt the platform key storage. You will need the same password for all subsequent runs.

**Best practice:** Configure password in `$GRADLE_USER_HOME/gradle.properties`:
```properties
platform.password=your_secure_password_here
```

**Important:** Use the Gradle user home directory (`$GRADLE_USER_HOME`), not the project directory, to avoid committing secrets to git.

## Data Directories

The platform automatically creates the following directories for persistent data:
- `~/xqiz.it/platform` - Platform configuration and data
- `~/xqiz.it/accounts` - Account information

## Shutdown Mechanisms

### Recommended: platformCLI

From within the platformCLI session:
```bash
shutdown
```

Or start platformCLI and run shutdown in one command:
```bash
xec -L build/install/platform/lib build/install/platform/lib/platformCLI.xtc \
  https://xtc-platform.localhost.xqiz.it:8090 admin:[password] shutdown
```

### Direct curl

**With standard ports (80/443):**
```bash
curl -k -H "Host: xtc-platform.localhost.xqiz.it" \
  -X POST https://xtc-platform.localhost.xqiz.it/host/shutdown
```

**With non-privileged ports (8080/8090):**
```bash
curl -k --resolve xtc-platform.localhost.xqiz.it:8090:127.0.0.1 \
  -H "Host: xtc-platform.localhost.xqiz.it" \
  -X POST https://xtc-platform.localhost.xqiz.it:8090/host/shutdown
```

**Note:** The `--resolve` flag and explicit `Host` header (without port) are required when using non-standard ports due to the DNS localhost resolution.

**Important:** If you do not stop the server cleanly, the next start-up will be much slower, since the databases on the server will need to be recovered.

## Docker Build Details

### Multi-Stage Build Architecture

The Dockerfile uses a multi-stage build with the official XDK base image from GitHub Container Registry:

**Stage 1: Platform Builder**
- Base image: `eclipse-temurin:25-jdk-alpine`
- Includes Node.js for building the web UI
- Gradle compiles all platform modules
- The gradle-node-plugin automatically handles the Quasar web UI build

**Stage 2: Runtime**
- Base image: `ghcr.io/xtclang/xvm:latest` (minimal XDK image)
- Contains only the XDK and compiled platform artifacts
- Final image size: approximately **145MB**

### Build Cache Optimization

Cache mounts are used for Gradle and Yarn dependencies to speed up rebuilds:
- First build downloads all dependencies
- Subsequent builds reuse cached dependencies and are much faster

### Docker vs Podman

The commands use `docker`, but `podman` can be used interchangeably. The only difference is that `podman` lacks the optimized buildx, which can be dropped from the command line:

```bash
# Docker
docker buildx build -t xtc-platform:latest .

# Podman
podman build -t xtc-platform:latest .
```

### Port Forwarding Notes

**Important:** Running the PAAS in Docker does NOT require the macOS port-forwarding setup described above. In fact, port-forwarding must be disabled/removed when running in Docker, as Docker handles port mapping internally.

## Gradle Build System

### Parallel Builds

This is a parallel Gradle build. Build tasks run concurrently for better performance.

**Important:** Don't run `clean` with other tasks in parallel builds:
- **Wrong:** `./gradlew clean build`
- **Correct:** `./gradlew clean && ./gradlew build`

### Dependency Management

The build system automatically downloads all required dependencies:
- **Node.js** and **Yarn** - Downloaded and managed by the gradle-node-plugin
- **XDK** - Resolved as a Maven dependency
- **All other dependencies** - Managed by Gradle

The project includes a Gradle wrapper (`./gradlew`), so you don't need to install Gradle separately.

### installDist Task

The `installDist` task:
- Copies all compiled modules to `build/install/platform/lib/`
- Generates `cfg.json` from the template
- Creates a deployable distribution

**When to use:**
- Creating a deployable distribution
- Running with `xec` directly

## platformCLI

The platformCLI provides a comprehensive interface for platform management.

### Features

- **Server management:** config, shutdown, debug
- **Application management:** register, start, stop, logs, stats
- **Module management:** upload, list
- **User/account management**

### Authentication

The CLI authenticates using the URL format:
```
https://hostname[:port] username:password
```

It communicates with the platform via REST endpoints.

### Usage

```bash
xec -L build/install/platform/lib build/install/platform/lib/platformCLI.xtc \
  https://xtc-platform.localhost.xqiz.it:8090 admin:[password]
```

Type `help` within the CLI to see all available commands.

## SSL Certificates

The platform generates self-signed SSL certificates for local development. When accessing the platform via HTTPS, you will receive browser warnings about the unverifiability of the website and its certificate. This is expected behavior for local development.
