# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# IMPORTANT: Separate base version and vendor for Java to avoid $3 unbound error
FROM debian:latest AS builder

ARG JAVA_VERSION=21.0.5-tem
ARG NVM_VERSION="v0.40.1"
ARG YARN_VERSION="1.22.22"
ARG NODE_VERSION="v20.18.1"
ARG GRADLE_VERSION=8.14

# Install Git and build essentials (for make)
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    curl \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# --- Install SDKMan, Java, and Gradle ---
# SDKMan requires a specific directory, typically ~/.sdkman.
# We'll set it to /root/.sdkman for the root user.
ENV HOME=/root
ENV SDKMAN_DIR="${HOME}/.sdkman"
# Crucial: Set BASH_ENV to automatically source sdkman-init.sh for all subsequent bash shells.
# This makes the 'sdk' command available without needing to explicitly 'source' it in every RUN.
ENV BASH_ENV="${SDKMAN_DIR}/bin/sdkman-init.sh"

# this SHELL command is needed to allow using source
SHELL ["/bin/bash", "-c"]

# Install SDKMan itself. Note: using the shell form with 'bash -c' due to SHELL instruction.
# rcupdate=false prevents it from trying to modify .bashrc, etc.
RUN curl -sSL 'https://get.sdkman.io?rcupdate=false' | bash

RUN source "/root/.sdkman/bin/sdkman-init.sh"   \
    && sdk install java "${JAVA_VERSION}" \
    && sdk install gradle "${GRADLE_VERSION}" \
    && sdk flush temp \
    && sdk flush archives \
    && sdk flush broadcast \
    && sdk flush version \
    && sdk use java "${JAVA_VERSION}" \
    && sdk use gradle "${GRADLE_VERSION}"

ENV SDKMAN_DIR=/root/.sdkman
ENV JAVA_HOME="${SDKMAN_DIR}/candidates/java/current"
ENV GRADLE_HOME="${SDKMAN_DIR}/candidates/gradle/current"

RUN mkdir -p /root/xtclang/xvm && \
    cd /root/xtclang && \
    git clone https://github.com/xtclang/xvm.git

ENV XVM_HOME=/root/xtclang/xvm

RUN cd "${XVM_HOME}" && \
    # compile the XDK
    ./gradlew xdk:installWithLaunchersDist && \
    cd xdk/build/install && \
    ln -s $(ls -td -- */ | head -n 1) xdk && \
    echo XVM setup complete.

ENV PATH="${XVM_HOME}/xdk/build/install/xdk/bin/:${PATH}"

RUN curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

ENV NVM_DIR=/root/.nvm

RUN . "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm use "${NODE_VERSION}" \
    && npm install -g "yarn@${YARN_VERSION}" \
    && nvm cache clear

ENV PATH="${NVM_DIR}/versions/node/${NODE_VERSION}/bin:${PATH}"

# copy over the whole directory instead of pulling it from github
RUN mkdir -p /root/xtclang/platform
COPY . /root/xtclang/platform

# build the platform
RUN . "${NVM_DIR}/nvm.sh" \
    && cd /root/xtclang/platform/platformUI/gui \
    # because we use the local copy of platform there might already be a node_modules. \
    # eslint is a module that is platform dependent so if our host is a Mac but here we build for Linux \
    # that means we have to start from scratch
    && rm -rf node_modules \
    && npm install \
    && npm install -g "@quasar/cli" \
    && cd ../.. \
    && gradle clean  \
    && gradle build

# --- Stage 2: Runtime ---
# Start from a minimal Debian image (e.g., debian:slim or debian:bookworm-slim)
# or even scratch if literally nothing else is needed, but typically a base OS is good.
FROM debian:bookworm-slim AS runtime

# the ports we are listening to
EXPOSE 8080 8090

ENV HOME=/root
ENV XVM_HOME="${HOME}/xtclang/xvm"
ENV PLATFORM_HOME="${HOME}/xtclang/platform"
ENV SDKMAN_DIR="${HOME}/.sdkman"
# Set JAVA_HOME and XDK_HOME directly as ENV variables in the runtime image.
# These will be available to your application.
# SDKMan installs Java to a specific path, so we use that.
ENV JAVA_HOME="${SDKMAN_DIR}/candidates/java/current"
ENV XDK_HOME="${XVM_HOME}/xdk/build/install/xdk"

# Copy the entrypoint script into the container and make it executable
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

# 1. CRITICAL: This MUST be the first RUN instruction in this stage.
# It installs 'mkdir' (from coreutils) and other essential tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    # Create the target directory for the tools
    && /bin/mkdir -p "${XVM_HOME}/xdk" \
    "${PLATFORM_HOME}/lib"  \
    # this is where the kernel is looking for the config
    /root/xqiz.it \
    "${SDKMAN_DIR}" \
    && chmod +x /usr/local/bin/entrypoint.sh

# Add the directory containing your executables to the PATH in the runtime image.
ENV PATH="${XDK_HOME}/bin:${JAVA_HOME}/bin:/bin:${PATH}"

# Copy the whold XDK from the builder image
COPY --from=builder "${XVM_HOME}/xdk" "${XVM_HOME}/xdk"
COPY --from=builder "${PLATFORM_HOME}/lib" "${PLATFORM_HOME}/lib"
COPY --from=builder "${JAVA_HOME}" "${JAVA_HOME}"

WORKDIR "${PLATFORM_HOME}"

ENV PASSWORD=""
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the default arguments for your application (xec).
# These arguments ("-L", ".", "./kernel.xtc") will be passed to your entrypoint.sh script as "$@".
# The password will be appended by the entrypoint.sh script.
CMD ["-L", "./lib", "./lib/kernel.xtc"]
