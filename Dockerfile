# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# --- Stage 1: UI Builder ---
# Use official Node.js image to build the UI (major version only)
FROM node:22 AS ui-builder

WORKDIR /workspace/platformUI/gui

# Install Quasar CLI globally (Yarn already included in node:22)
RUN npm install -g @quasar/cli

# Copy package files first for better caching
COPY platformUI/gui/package*.json ./

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.npm \
    npm install

# Copy the rest of the UI source
COPY platformUI/gui .

# Build the UI
RUN npm run build

# --- Stage 2: Platform Builder ---
# Use the XDK base image to build the platform
FROM ghcr.io/xtclang/xvm:latest AS builder

ENV HOME=/root
ENV PLATFORM_HOME=/root/xtclang/platform
ENV GRADLE_USER_HOME=/cache/gradle

WORKDIR ${PLATFORM_HOME}

# Copy the entire platform source
COPY . ${PLATFORM_HOME}

# Copy the built UI artifacts from the ui-builder stage
COPY --from=ui-builder /workspace/platformUI/gui/dist ${PLATFORM_HOME}/platformUI/gui/dist

# Build the platform with Gradle using cache mount and proper flags
# Build platformUI manually after other modules since it has GUI dependencies
RUN --mount=type=cache,target=/cache/gradle \
    ./gradlew build -x :platformUI:build --no-daemon --build-cache && \
    xcc -v -o lib -L lib -r platformUI/gui/dist platformUI/src/main/x/platformUI.x

# --- Stage 3: Runtime ---
# Use the XDK base image which already contains Java and the XDK
FROM ghcr.io/xtclang/xvm:latest AS runtime

# the ports we are listening to
EXPOSE 8080 8090

ENV HOME=/root
ENV PLATFORM_HOME="${HOME}/xtclang/platform"

# Copy the entrypoint script into the container and make it executable
COPY ./docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Create the platform directory structure
RUN mkdir -p "${PLATFORM_HOME}/lib" \
    # this is where the kernel is looking for the config
    /root/xqiz.it \
    && chmod +x /usr/local/bin/entrypoint.sh

# Copy the platform library from the builder image
COPY --from=builder "${PLATFORM_HOME}/lib" "${PLATFORM_HOME}/lib"

WORKDIR "${PLATFORM_HOME}"

ENV PASSWORD=""
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set the default arguments for your application (xec).
# These arguments ("-L", ".", "./kernel.xtc") will be passed to your entrypoint.sh script as "$@".
# The password will be appended by the entrypoint.sh script.
CMD ["-L", "./lib", "./lib/kernel.xtc"]
