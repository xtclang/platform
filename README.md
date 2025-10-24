# Platform as a Service #

This is the public repository for the open source Ecstasy PaaS project, sponsored by
[xqiz.it](http://xqiz.it).

## Status:

This project is being actively developed, but is not yet considered a production-ready release.

## Layout

The project is organized as a number of sub-projects, with the important ones to know about being:

* The *common* library (`./common`), contains common interfaces shared across platform modules.
* The *kernel* library (`./kernel`), contains the boot-strapping functionality. It's responsible for
  starting system services and introducing them to each other.
* The *host* library (`./host`), contains the manager for hosted applications
* The *platformDB* library (`./platformDB`), contains the platform database.
* The *platformUI* library (`./platformUI`), contains the end-points for the platform web-application.

## Installation

Clone [the platform repository](https://github.com/xtclang/platform) to your local machine:

    git clone https://github.com/xtclang/platform.git $PROJECT_DIR

Throughout this document, `$PROJECT_DIR` refers to the location where you cloned the platform
repository. For example, you might set `PROJECT_DIR=~/Development/platform`.

**That's it!** The build system will automatically download all required dependencies including the
XDK, Node.js, Yarn, and all modules.

## Quick Start

```bash
cd $PROJECT_DIR
./gradlew build
./gradlew up        # Start platform in background
# Open https://xtc-platform.localhost.xqiz.it:8090
./gradlew down      # Stop platform cleanly
```

**Note:** This is a parallel Gradle build. Don't run `clean` with other tasks in parallel builds
(e.g., avoid `./gradlew clean build`). Run separately: `./gradlew clean && ./gradlew build`

## Steps to test the PAAS functionality:

1. **DNS Configuration Note**

   The `xqiz.it` PAAS uses a **non-standard DNS setup** where `*.localhost.xqiz.it` is configured
   in public DNS to resolve to `127.0.0.1`:

   ```bash
   # DNS Record (configured at xqiz.it's nameservers: ns81/ns82.domaincontrol.com)
   *.localhost.xqiz.it.  600  IN  A  127.0.0.1
   ```

   **What this means:**
   - Any subdomain under `localhost.xqiz.it` (like `xtc-platform.localhost.xqiz.it`) resolves to
     your local machine
   - This is **publicly visible DNS** pointing to localhost, which is highly unusual
   - The main `xqiz.it` domain points to real public IPs (AWS), but the `localhost` subdomain
     wildcard points to loopback

   **Why this is non-standard:**
   - Most DNS rebind protection will block this (browsers/routers preventing public DNS from
     returning private IPs)
   - Creates potential security concerns (public domain cookies/auth on localhost)
   - Goes against typical DNS best practices of not mixing public DNS with localhost resolution

   **Tradeoffs:**
   - **Pro**: Allows clean URLs without `/etc/hosts` editing or local DNS server
   - **Con**: DNS rebind protection may block it on some networks/routers
   - **Con**: Security implications of public domain credentials on local services

   **Testing resolution:**
   ```bash
   ping xtc-platform.localhost.xqiz.it  # Should return 127.0.0.1
   ```

   If resolution fails, your DNS server likely has rebind protection. For example, on Verizon
   routers, add an exception for "127.0.0.1" in DNS Server settings: "Exceptions to DNS Rebind
   Protection" (Advanced - Network Settings - DNS Server).

   **Alternative approach**: Use `localhost:8090` directly instead of the DNS-based URL.

2. No additional software installation is required! The Gradle build automatically handles:
   - **Node.js** and **Yarn** (downloaded and managed by the gradle-node-plugin)
   - **XDK** (resolved as a Maven dependency)
   - **All dependencies** (managed by Gradle)

   The project includes a Gradle wrapper (`./gradlew`), so you don't even need to install Gradle
   separately.

3. **Platform Ports** (defaults to 8080/8090, no special privileges required)

   The platform defaults to **HTTP 8080** and **HTTPS 8090**.

   To change ports:
   - **Before first build** (optional): Set in `$GRADLE_USER_HOME/gradle.properties`:
     ```
     platform.httpPort=3000
     platform.httpsPort=3443
     ```
     These values will be embedded in the kernel module and used when `~/xqiz.it/platform/cfg.json`
     is created on first run.

   - **After first run**: Edit `~/xqiz.it/platform/cfg.json` and restart the platform

   - **Via command line** (temporary):
     `./gradlew build -Pplatform.httpPort=3000 -Pplatform.httpsPort=3443`

   ### Using Privileged Ports 80/443 (Optional - macOS)

   If you really want to use standard HTTP/HTTPS ports (80/443) on macOS, you'll need to set up
   port forwarding since these are privileged ports:

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

   **Alternative**: Use a container runtime (Docker/Podman) which handles port mapping without
   requiring privileged access.

4. Build the platform services using the Gradle wrapper:

       cd $PROJECT_DIR
       ./gradlew build

   Note: The first build will download all dependencies (including Node.js, Yarn, Quasar, and XDK)
   and may take a few minutes. Subsequent builds will be much faster.

5. **(Optional)** Install the platform distribution:

       ./gradlew installDist

   This copies all compiled modules to `build/install/platform/lib/` and generates `cfg.json`.
   Useful for:
   - Creating a deployable distribution
   - Running with `xec` directly (Method 3 below)

   **Not required for local development** - `./gradlew up` works directly from build outputs.

6. **(Recommended)** Configure your platform password as a Gradle property for security and
   convenience:

   Create or edit `$GRADLE_USER_HOME/gradle.properties` and add:

       platform.password=your_secure_password_here

   **Important:** This file is in your Gradle user home directory, not the project directory, so
   your password won't be committed to `git`. Of course it works to use gradle.properties, but that
   has the risk of secrets getting into source control, and is not the preferred pattern.

7. Start the platform using one of these methods:

   **Method 1: Using Gradle (recommended)**

        ./gradlew up

   **Method 2: Using Gradle with password on command line**

        ./gradlew up -Pplatform.password=your_password

   **Method 3: Using xec directly (requires installDist first)**

        ./gradlew installDist
        xec -L build/install/platform/lib build/install/platform/lib/kernel.xtc your_password

   **Notes:**
   - The password you choose during the very first run will be used to encrypt the platform key
     storage. You will need the same password for all subsequent runs.
   - The platform will automatically create `~/xqiz.it/platform` and `~/xqiz.it/accounts`
     directories for persistent data.
   - The `cfg.json` configuration file will be automatically created from a template on first run.

8. Open the locally hosted platform web page:

   **With default ports (8080/8090):**
   ```
   http://xtc-platform.localhost.xqiz.it:8080
   https://xtc-platform.localhost.xqiz.it:8090
   ```

   **With privileged ports (80/443):**
   ```
   http://xtc-platform.localhost.xqiz.it
   https://xtc-platform.localhost.xqiz.it
   ```

   The build completion message shows the exact URLs based on your configured ports.

   **Note:** Using the locally-created (self-signed) certificate, you will receive warnings from
   the browser about the unverifiability of the website and its certificate.

9. Follow the instructions from the [Examples](https://github.com/xtclang/examples) repository to
   build and "upload" a web application.
10. Log into the "Ecstasy Cloud" platform using the pre-defined test user "admin" and the password
    "password".
11. Go to the "Modules" panel and install any of the example module (e.g. "welcome.examples.org").
12. Go to the "Application" panel, register a deployment (e.g. "welcome") and "start" it
13. Click on the URL to launch your application web page.
14. To control the hosting platform via the command line interface (CLI), start the command line
    tool:

    xec -L build/install/platform/lib build/install/platform/lib/platformCLI.xtc https://xtc-platform.localhost.xqiz.it admin:[password]

    Type "help" to see all available commands.

15. To stop the server cleanly, use a CLI "shutdown" command or from a separate shell run this:

    **With standard ports (80/443):**

        curl -k -H "Host: xtc-platform.localhost.xqiz.it" -X POST https://xtc-platform.localhost.xqiz.it/host/shutdown

    **With non-privileged ports (8080/8090):**

        curl -k --resolve xtc-platform.localhost.xqiz.it:8090:127.0.0.1 -H "Host: xtc-platform.localhost.xqiz.it" -X POST https://xtc-platform.localhost.xqiz.it:8090/host/shutdown

    **Or use the Gradle task:**

        ./gradlew down

    **Note:** The `--resolve` flag and explicit `Host` header (without port) are required when
    using non-standard ports due to the DNS localhost resolution. The `down` task handles this
    automatically.

    If you do not stop the server cleanly, the next start-up will be much slower, since the
    databases on the server will need to be recovered.

## PAAS in Docker #
> NOTE: Running the PAAS in Docker does NOT require port-forwarding as described above.
> In fact port-forwarding must be disabled/removed.

### Build

The Dockerfile uses a multi-stage build with the official XDK base image from GitHub Container
Registry.

**Note:** The commands below use `docker`, but `podman` can be used interchangeably. The only thing
`podman` lacks is the optimized buildx, which can be dropped from the command line if running
`podman`:

```shell
docker buildx build -t xtc-platform:latest .
```

The build uses a two-stage process:
1. **Platform Builder** - Uses `eclipse-temurin:25-jdk-alpine` with Node.js to build everything
   (Gradle compiles all platform modules, and the gradle-node-plugin automatically handles the
   Quasar web UI build)
2. **Runtime** - Uses the minimal `ghcr.io/xtclang/xvm:latest` base image with only the XDK and
   compiled platform artifacts

The final image is approximately **145MB** in size.

**Note:** Cache mounts are used for Gradle and Yarn dependencies to speed up rebuilds. The first
build downloads dependencies, but subsequent builds will be much faster.

### Run
#### username:password
The PAAS requires a username and password to login.
* The default username is **admin**
* This password is passed in using **-e PASSWORD=[password]**.

#### PAAS configuration
The networking part of the PAAS is configured with a JSON formatted file named **cfg.json**.
The PAAS is looking for the config file inside the container at **~/xqiz.it/platform**.
If a **cfg.json** is already present then it will be loaded and processed.
Otherwise it will be created from the default template which is here
[cfg.json](./kernel/src/main/resources/cfg.json) .

Docker allows mapping a host folder into the container. This allows accessing the files created by
the PAAS. It is suggested to use the same location as if the PAAS is run locally on the machine.
Create the local folder which will be mapped by Docker.

```shell
mkdir -p ~/xqiz.it
```

If you want to make changes to **cfg.json** then start the PAAS once, locate the config file, amend
it and restart the container to pick up the changes.

#### Run it for the first time

Substitute port forwarding as configured, if required, and execute something like this:

```shell
docker run -e PASSWORD=[password] -p 80:8080 -p 443:8090 -v ~/xqiz.it:/root/xqiz.it --name xtc-platform xtc-platform:latest
```

#### Restart
```shell
docker restart xtc-platform
```

#### Stop
```shell
docker stop xtc-platform
```

#### Teardown
Removing the container and the image in case they are not needed anymore
```shell
docker rm xtc-platform && docker rmi xtc-platform:latest
```

### Accessing the PAAS
Use the browser to access the PAAS e.g. https://xtc-platform.localhost.xqiz.it

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