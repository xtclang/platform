# Ecstasy Platform as a Service

This is the public repository for the open source Ecstasy PaaS project, sponsored by [xqiz.it](http://xqiz.it).

**Status:** This project is being actively developed, but is not yet considered a production-ready release.

## Self-Contained Build System

The Ecstasy Platform features a **fully automated, self-contained build system**. The build automatically downloads and manages all required dependencies including the XDK (Ecstasy Development Kit), Node.js, Yarn, Quasar, and all Gradle dependencies. The goal of this build system is to provide a zero-configuration setup where you can clone the repository and build immediately without any manual dependency installation.

The project includes a Gradle wrapper (`./gradlew`), so you don't even need to install Gradle separately. Simply clone and build!

## Project Structure

* `common/` - Common interfaces shared across platform modules
* `kernel/` - Boot-strapping functionality that starts system services
* `host/` - Manager for hosted applications
* `platformDB/` - Platform database
* `platformUI/` - End-points for the platform web application and Quasar UI

For technical details about DNS configuration, ports, build internals, and advanced configuration, see [doc/internals.md](doc/internals.md).

## Prerequisites

**None!** Everything is automated. Just ensure you have:
- A Java Development Kit (JDK) installed (for running Gradle)
- Git for cloning the repository

The build system will automatically handle:
- ✅ XDK (Ecstasy development kit) - resolved as Maven dependency
- ✅ Node.js and Yarn - downloaded and managed by gradle-node-plugin
- ✅ Quasar framework - installed automatically during UI build
- ✅ All other dependencies - managed by Gradle

## Installation

Clone the repository:

```bash
git clone https://github.com/xtclang/platform.git
cd platform
```

## Quick Start

(This example assums you are using the non-privileged ports)

```bash
# Build and create distribution
./gradlew installDist  # depends on build in the Gradle lifecycle
xec -L build/install/platform/lib build/install/platform/lib/kernel.xtc your_password
# Open https://xtc-platform.localhost.xqiz.it:8090
# Stop via platformCLI or send shutdown request
```

**Note:** This is a parallel Gradle build. Don't run `clean` with other tasks simultaneously. Use: `./gradlew clean && ./gradlew build`

## DNS and Network Setup

The platform uses the domain `xtc-platform.localhost.xqiz.it` which resolves to `127.0.0.1`.

### Verifying DNS Resolution

Test that the platform address resolves correctly:

```bash
ping xtc-platform.localhost.xqiz.it
```

This should return `127.0.0.1`. If it doesn't resolve, see DNS troubleshooting in step 4 below or [doc/internals.md](doc/internals.md) for details.

### Optional: Using Standard HTTP/HTTPS Ports

**Note:** The platform defaults to ports 8080/8090 which work without special configuration. This section is only needed if you want to use standard ports 80/443.

If you want to use privileged ports (80/443) on macOS, you'll need port forwarding:

1. Create a file `~/xqiz.it/platform/port-forwarding.conf`:
   ```
   rdr pass on lo0 inet proto tcp from any to self port 80  -> 127.0.0.1 port 8080
   rdr pass on lo0 inet proto tcp from any to self port 443 -> 127.0.0.1 port 8090
   ```

2. Enable port forwarding (requires sudo and must be re-run after each OS reboot):
   ```bash
   sudo pfctl -evf ~/xqiz.it/platform/port-forwarding.conf
   ```

**Alternative:** Use Docker/Podman which handle port mapping without requiring privileged access, or simply use the default ports 8080/8090.

## Getting Started

### 1. Build the Platform

```bash
./gradlew build
```

The first build downloads all dependencies (XDK, Node.js, Yarn, Quasar) and may take a few minutes. Subsequent builds are much faster.

### 2. Configure Password (Recommended)

For security, set your password in `$GRADLE_USER_HOME/gradle.properties`:

```properties
platform.password=your_secure_password_here
```

**Important:** Use `$GRADLE_USER_HOME/gradle.properties` (not project's `gradle.properties`) to avoid committing secrets to git.

### 3. Install Distribution and Start the Platform

```bash
./gradlew installDist
xec -L build/install/platform/lib build/install/platform/lib/kernel.xtc your_password
```

Or if you configured password in `gradle.properties`:

```bash
./gradlew installDist
xec -L build/install/platform/lib build/install/platform/lib/kernel.xtc $(grep platform.password $GRADLE_USER_HOME/gradle.properties | cut -d'=' -f2)
```

The password chosen on first run encrypts the platform key storage and must be used for all subsequent runs.

### 4. Access the Platform

Open in your browser:
- **HTTP:** http://xtc-platform.localhost.xqiz.it:8080
- **HTTPS (recommended):** https://xtc-platform.localhost.xqiz.it:8090

**Note:** Self-signed certificates will trigger browser security warnings (expected for local development).

**DNS Troubleshooting:** If the URL doesn't resolve:
- Use `localhost:8090` directly, or
- See [doc/internals.md](doc/internals.md) for DNS rebind protection workarounds

### 5. Login and Deploy an Application

1. Login with test credentials: **username:** `admin`, **password:** `password`
2. Build an example app from the [Examples](https://github.com/xtclang/examples) repository
3. Go to "Modules" panel and install your module (e.g., `welcome.examples.org`)
4. Go to "Application" panel, register a deployment (e.g., `welcome`) and start it
5. Click the URL to launch your application

### 6. Stop the Platform

Use the platformCLI to shutdown cleanly:

```bash
xec -L build/install/platform/lib build/install/platform/lib/platformCLI.xtc \
  https://xtc-platform.localhost.xqiz.it:8090 admin:[password] shutdown
```

Or send a shutdown request directly (TO BE DEPRECATED):
If you don't have a privileged port deployment, you may need to use the --resolve argument to force route the
xtc-platform.localhost.* URL to be overridden.

```bash
curl -k --resolve xtc-platform.localhost.xqiz.it:8090:127.0.0.1 \
  -H "Host: xtc-platform.localhost.xqiz.it" \
  -X POST https://xtc-platform.localhost.xqiz.it:8090/host/shutdown
```

**Important:** Always stop the server cleanly. An unclean shutdown requires database recovery on next startup, which is much slower.

## Platform CLI

Control the platform from the command line:

```bash
./gradlew installDist  # Required first time
xec -L build/install/platform/lib build/install/platform/lib/platformCLI.xtc \
  https://xtc-platform.localhost.xqiz.it:8090 admin:[password]
```

Type `help` to see available commands for managing servers, applications, modules, and users.

## Configuration

**Ports:** The platform defaults to HTTP 8080 and HTTPS 8090. To change ports, see [doc/internals.md](doc/internals.md).

**Configuration file:** `~/xqiz.it/platform/cfg.json` (auto-generated on first run from [kernel/src/main/resources/cfg.json](kernel/src/main/resources/cfg.json))

**Data directories:** The platform automatically creates `~/xqiz.it/platform` (for platform configuration and data) and `~/xqiz.it/accounts` (for account information) on first run.

## Running in Docker

> **Note:** Docker handles port mapping internally - do NOT use the macOS port-forwarding setup described in [doc/internals.md](doc/internals.md).

### Build the Image

```bash
docker buildx build -t xtc-platform:latest .
# Or with podman:
podman build -t xtc-platform:latest .
```

The multi-stage build produces a ~145MB image. First build downloads dependencies; subsequent builds use cache and are faster. For build architecture details, see [doc/internals.md](doc/internals.md).

### Run the Container

The Docker image configures the platform to run on standard HTTP/HTTPS ports (80/443) inside the container. Since containers run as root, there are (currently) no privilege restrictions.

**Option 1: Privileged ports on host (80/443)**

```bash
mkdir -p ~/xqiz.it
docker run --rm -e PASSWORD=password -p 80:80 -p 443:443 -v ~/xqiz.it:/root/xqiz.it --name xtc-platform xtc-platform:latest
```

Access the platform at:
- **HTTPS:** https://xtc-platform.localhost.xqiz.it

Docker handles the privileged port binding on the host, so you don't need macOS port-forwarding.

**Option 2: Non-privileged ports on host (8080/8090)**

```bash
mkdir -p ~/xqiz.it
docker run --rm -e PASSWORD=password -p 8080:80 -p 8090:443 -v ~/xqiz.it:/root/xqiz.it --name xtc-platform xtc-platform:latest
```

Access the platform at:
- **HTTPS:** https://xtc-platform.localhost.xqiz.it:8090

This maps the container's internal 80/443 to host ports 8080/8090.

**Podman equivalent (privileged ports):**

```bash
mkdir -p ~/xqiz.it
podman run --rm -e PASSWORD=password -p 80:80 -p 443:443 -v ~/xqiz.it:/root/xqiz.it --name xtc-platform xtc-platform:latest
```

**Configuration:** The platform uses `cfg.json` at `~/xqiz.it/platform/cfg.json` (auto-generated from template on first run).

**Security Note:** The default password is `password`. For production use, change it:
```bash
docker run -e PASSWORD=your_secure_password ...
```

### Access the Platform

Login credentials:
- **Username:** `admin`
- **Password:** `password` (or your custom password if set)

### Manage the Container

```bash
docker stop xtc-platform               # Stop (container auto-removes with --rm)
docker rmi xtc-platform:latest         # Remove image
```

## Build/CI Integration

For automated testing and CI/CD pipelines, you can create custom Gradle tasks that bootstrap the platform from the `installDist` output directory. Here's an example of how to define `up` and `down` tasks:

```kotlin
// Configure the XTC plugin's runtime behavior
xtcRun {
    verbose = true
    detach = true  // if this is executed from the install lifecycle, live on after the build has exited.
    modulePath.setFrom(layout.buildDirectory.dir("install/platform/lib"))
    module {
        moduleName = "kernel.xqiz.it"
        moduleArg(providers.gradleProperty("platform.password").orElse("password"))
    }
}

// Ensure runXtc depends on installDist
tasks.runXtc.configure {
    dependsOn(installDist)
}

// Up task: install distribution and run the platform
val up by tasks.registering {
    group = "application"
    description = "Start the platform in the background"
    dependsOn(tasks.runXtc)  // Uses the xtc plugin's runXtc task
    doLast {
        logger.lifecycle("Platform started.")
    }
}

// Down task: shutdown the platform via curl
val down by tasks.registering(Exec::class) {
    group = "application"
    description = "Shutdown the running platform"

    val httpsPort = platformHttpsPort  // Reference to your port property

    executable = "curl"
    argumentProviders.add {
        val port = httpsPort.get()
        listOf(
            "-k", "-f", "-s", "-S",
            "-m", "10",
            "--resolve", "xtc-platform.localhost.xqiz.it:$port:127.0.0.1",
            "-H", "Host: xtc-platform.localhost.xqiz.it",
            "-X", "POST",
            "https://xtc-platform.localhost.xqiz.it:$port/host/shutdown"
        )
    }

    isIgnoreExitValue = true
    doLast {
        if (executionResult.get().exitValue == 0) {
            logger.lifecycle("Platform shutdown command sent")
        } else {
            logger.error("Failed to shutdown the platform")
        }
    }
}
```

These tasks leverage the XTC Gradle plugin's `runXtc` task and the `installDist` configuration to automate platform lifecycle management. This approach is useful for:
- Continuous integration testing
- Automated deployment scripts
- Development environment setup scripts

**Note:** For production use, consider using the platformCLI instead of curl for more reliable shutdown handling.

## License

The license for source code is Apache 2.0, unless explicitly noted. We chose Apache 2.0 for its
compatibility with almost every reasonable use, and its compatibility with almost every license,
reasonable or otherwise.

The license for documentation (including any the embedded markdown API documentation and/or
derivative forms thereof) is Creative Commons CC-BY-4.0, unless explicitly noted.

To help ensure clean IP (which will help us keep this project free and open source), pull requests
for source code changes require a signed contributor agreement to be submitted in advance. We use
the Apache contributor model agreements (modified to identify this specific project), which can be
found in the [license](./LICENSE) file. Contributors are required to sign and submit an Ecstasy
Project Individual Contributor License Agreement (ICLA), or be a named employee on an Ecstasy
Project Corporate Contributor License Agreement (CCLA), both derived directly from the Apache
agreements of the same name. (Sorry for the paperwork! We hate it too!)

The Ecstasy name is a trademark owned and administered by The Ecstasy Project. Unlicensed use of the
Ecstasy trademark is prohibited and will constitute infringement.

The xqiz.it name is a trademark owned and administered by Xqizit Incorporated. Unlicensed use of the
xqiz.it trademark is prohibited and will constitute infringement.

All content of the project not covered by the above terms is probably an accident that we need to be
made aware of, and remains (c) The Ecstasy Project, all rights reserved.
