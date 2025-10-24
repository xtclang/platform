# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# --- Stage 1: Platform Builder ---
# Use a JDK base image to build the platform (Gradle requires javac)
FROM eclipse-temurin:25-jdk-alpine AS builder

# Build arguments for HTTP and HTTPS ports
ARG HTTP_PORT=8080
ARG HTTPS_PORT=8090

# Install Node.js for building platformUI (Alpine provides musl-compatible binaries)
# npm is required by gradle-node-plugin's yarnSetup task to install yarn
RUN apk add --no-cache nodejs npm

ENV HOME=/root
ENV PLATFORM_HOME=/root/xtclang/platform
ENV GRADLE_USER_HOME=/cache/gradle

# Pass port arguments to Gradle as project properties
ENV ORG_GRADLE_PROJECT_platform.httpPort=${HTTP_PORT}
ENV ORG_GRADLE_PROJECT_platform.httpsPort=${HTTPS_PORT}

WORKDIR ${PLATFORM_HOME}

# Copy the entire platform source
COPY . ${PLATFORM_HOME}

# Build the platform with Gradle using cache mount
# The gradle-node-plugin will use system Node.js instead of downloading
# Use --no-daemon and limit workers to reduce memory usage in Docker
RUN --mount=type=cache,target=/cache/gradle \
    --mount=type=cache,target=/cache/yarn \
    ./gradlew clean --refresh-dependencies --no-daemon --max-workers=2 -Pnode.download=false && \
    ./gradlew build --no-daemon --max-workers=2 -Pnode.download=false && \
    ./gradlew installDist --no-daemon -Pnode.download=false

# --- Stage 2: Runtime ---
# Use the XDK base image which already contains Java and the XDK
FROM ghcr.io/xtclang/xvm:latest AS runtime

# Redeclare build arguments for runtime stage
ARG HTTP_PORT=8080
ARG HTTPS_PORT=8090

# the ports we are listening to
EXPOSE ${HTTP_PORT} ${HTTPS_PORT}

ENV HOME=/root
ENV PLATFORM_HOME="${HOME}/xtclang/platform"

# Copy the entrypoint script into the container and make it executable
COPY ./docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Create the platform directory structure
# Note: /root/xqiz.it is where the kernel looks for config
RUN mkdir -p "${PLATFORM_HOME}/lib" \
    /root/xqiz.it \
    && chmod +x /usr/local/bin/entrypoint.sh

# Copy the installed platform distribution from the builder image
# installDist puts everything in build/install/platform/lib
COPY --from=builder "${PLATFORM_HOME}/build/install/platform/lib" "${PLATFORM_HOME}/lib"
COPY --from=builder "${PLATFORM_HOME}/build/install/platform/cfg.json" "${PLATFORM_HOME}/"

WORKDIR "${PLATFORM_HOME}"

ENV PASSWORD=""
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the default arguments for your application (xec).
# These arguments ("-L", ".", "./kernel.xtc") will be passed to your entrypoint.sh script as "$@".
# The password will be appended by the entrypoint.sh script.
CMD ["-L", "./lib", "./lib/kernel.xtc"]
