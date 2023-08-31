FROM homebrew/brew:4.1.4

# install essential tools and libraries
USER root
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y build-essential git

# install xvm
RUN brew tap xtclang/xvm \
    && brew install xdk-latest

# build the latest xvm from source and update the default
RUN git clone https://github.com/xtclang/xvm.git ~/xvm \
    && cd ~/xvm \
    && ./gradlew dist-local

# install JS tools
ARG NODE_VERSION=18.17.1
ARG NODE_PACKAGE=node-v$NODE_VERSION-linux-x64
ARG NODE_HOME=/opt/$NODE_PACKAGE

ENV NODE_PATH $NODE_HOME/lib/node_modules
ENV PATH $NODE_HOME/bin:$PATH

RUN curl https://nodejs.org/dist/v$NODE_VERSION/$NODE_PACKAGE.tar.gz | tar -xzC /opt/ \
    && npm install --global yarn

# build the platform
RUN mkdir -p ~/xqiz.it/platform \
    && keytool -genkeypair \
        -alias platform \
        -keyalg RSA \
        -keysize 2048 \
        -validity 365 \
        -dname "OU=Platform, O=[some.org], C=US" \
        -keystore ~/xqiz.it/platform/certs.p12 \
        -storetype PKCS12 -storepass qwerty \
    && keytool -genseckey \
        -alias cookies \
        -keyalg AES \
        -keysize 256 \
        -keystore ~/xqiz.it/platform/certs.p12 \
        -storetype PKCS12 \
        -storepass qwerty \
    && git clone https://github.com/azzazzel/xtc_platform.git ~/xtc_platform \
    && cd ~/xtc_platform && git checkout quasar_gui \
    && cd ~/xtc_platform/platformUI/old_gui && npm install \
    && cd ~/xtc_platform/platformUI/gui && npm install \
    && cd ~/xtc_platform && ~/xvm/gradlew build

WORKDIR /root/xtc_platform
CMD ["xec", "-L", "lib/", "lib/kernel.xtc", "qwerty"]