FROM gradle-8.6

# Platform as a Service

This is the public repository for the open source Ecstasy PaaS project, sponsored by [xqiz.it](http://xqiz.it).

## Layout

The project is organized as a number of sub-projects, with the important ones to know about being:

* The *common* library ([platform/common](./common)), contains common interfaces shared across platform modules.

* The *kernel* library ([platform/kernel](./kernel)), contains the boot-strapping functionality. It's responsible for
  starting system services and introducing them to each other.

* The *host* library ([platform/host](./host)), contains the manager for hosted applications.

* The *platformDB* library ([platform/platformDB](./platformDB)), contains the platform database.

* The *platformUI* library ([platform/platformUI](./platformUI)), contains the end-points for the platform
  web-application.

## Installation

1. Please follow steps 1-3 of the [XDK Installation](https://github.com/xtclang/xvm#installation).
2. Clone [the platform repository](https://github.com/xtclang/platform) to your local machine.

## Steps to test the PAAS functionality:

### Provide properties named `gitHubUser` and `gitHubPassword`

The platform expects to be able to read artifacts from the GitHub Maven Package Repository,
and requires credentials to do so. Later we will have this repo retrieve its artifacts from
gradlePluginPortal and mavenCentral. To understand how to set up these credentials, follow
the instructions in the [xtc-template-app](https://github.com/xtclang/xtc-app-template/blob/master/README.md)
and if you want to get more detail on this, take a look at the comment in the 
[xtc-template-app settings](https://github.com/xtclang/xtc-app-template/blob/master/settings.gradle.kts)

Hence, ensure that you have properties named "gitHubUser" and "gitHubToken" set up in your
environments, and that the token has read:package privileges for the GitHub Maven Repo. 

If you can build and run the [xtc-template-app](https://github.com/xtclang/xtc-app-template/tree/master), and 
have that correctly configured, you can skip this step.

### Create a local (or containerized) platform environment

Note that steps 1 and 2 are temporary, and step 2 needs to be re-executed every time after an OS reboot. Steps 3-8 need
to be done just once. Or Dockerize and never have to think about this again. The platform should also be distributed
as a container/Dockerfile/docker in the near future, so that you won't have to do any of these manual steps. 

1. Create `xqiz.it` subdirectory under the user home directory for the platform persistent data. The subdirectory "
   platform" will be used to keep the platform operational information and subdirectory "users" for hosted applications.

2. Create a file `~/xqiz.it/platform/port-forwarding.conf` with the following content:

```
   rdr pass on lo0 inet proto tcp from any to self port 80  -> 127.0.0.1 port 8080
   rdr pass on lo0 inet proto tcp from any to self port 443 -> 127.0.0.1 port 8090
```

3. Run the following command to redirect http and https traffic to unprivileged ports:

```
   sudo pfctl -evf ~/xqiz.it/platform/port-forwarding.conf
```

4. Make sure you can ping the local platform address:

```
   ping xtc-platform.localhost.xqiz.it
```

   The domain name `xtc-platform.localhost.xqiz.it` should resolve to `127.0.0.1`. This allows the same xqiz.it
   cloud-hosted platform to be self-hosted on the `localhost` loop-back address, enabling local and disconnected
   development.

   If that address fails to resolve you may need to change the rules on you DNS server. For example, for Verizon routers
   you would need add an exception entry for `127.0.0.1` to your DNS Server settings: "Exceptions to DNS Rebind
   Protection" (Advanced - Network Settings - DNS Server)

   TODO: Why not just add an /etc/host entry, or run a dns server in a co-deployed container?

5. Create a self-signed certificate for the platform web server. For example:

```
    keytool -genkeypair -alias platform -keyalg RSA -keysize 2048 -validity 365 -dname "OU=Platform, O=[your name], C=US" -keystore ~/xqiz.it/platform/certs.p12 -storetype PKCS12 -storepass [password]
```

6. Add a symmetric key to encode the cookies:

```
    keytool -genseckey -alias cookies -keyalg AES -keysize 256 -keystore ~/xqiz.it/platform/certs.p12 -storetype PKCS12 -storepass [password]
```

7. If you want to run with an XDK installation and not just let the plugin sort it out, make sure you
   have [xdk-latest](https://github.com/xtclang/xvm#readme) installed.

8. Make sure you have a Java runtime installed for bootstrapping. It should really be enough with any
   old Java, just so that you can run the Gradle wrapper. The Java toolchains support should download the
   latest compatible JDK environment for you, to build and run the XTC Platform.

9. Make sure that when you issue Gradle commands, you do it either through the Gradle wrapper script, or from
   inside your IDE, that you are sure knows about your wrapper script. Any IDE in which you import this project
   should pick that up and grab the appropriate runtimes and dependencies.

   *It is recommended that you *do not* keep a Gradle executable on your system path to build the project, but 
   instead use the Gradle wrapper script (or its IDE integration) for every task you want to execute.* 

10.Build and run the server.

    You can provide the password for your keystore as a Gradle property, by adding a line on the form
    `keystorePassword=<your-password>` to the `$GRADLE_USER_HOME/gradle.properties`. This is 
    the customary way to add secrets outside source control. You can also place it in the environment
    variable `ORG_GRADLE_PROJECT_password`, or send it as a Gradle property on the launcher line, like this:

    * Note: The password you choose during the very first run will be used to encrypt the platform key storage.
      You will need the same password for all subsequent runs. If you do not provide a password, executing
      the launcher through one of the two methods described in this paragraph, will prompt for the password
      on `stdin`, which, while it works, is not compatible with scenarios like automatic CI/CD testing. 
      
Either build and run the server "the traditional way" (requires a local XDK installation) with: 

```
    ./gradlew build
    xec --verbose -L ./build/platform/ kernel.xqiz.it [password] 
```
     
or with the experimental: 

```
    ./gradlew run -PkeystorePassword=<your secret password>`
```

Note: the ./gradlew run task described in this paragraph is not meant as a production way of running
the platform. However, it can be quite handy to use for debugging poses with the debug = true flag
set in the XTC run configuration.

12. Open the [locally hosted platform web page](https://xtc-platform.localhost.xqiz.it):

    Note: Using the locally-created (self-signed) certificate from step 5 above, you will receive warnings from the
    browser about the unverifiability of the website and its certificate.

13. Follow the instructions from the [Examples](https://github.com/xtclang/examples) repository to build and "upload" a web application.

14. Log into the "Ecstasy Cloud" platform using the pre-defined test user "admin" and the password "password".

15. Go to the "Modules" panel and install any of the example module (e.g. "welcome.examples.org").

16. Go to the "Application" panel, register a deployment (e.g. "welcome") and "start" it

17. Click on the URL to launch your application web page.

18. To stop the server cleanly, from a separate shell or process, run this command:

```
    curl -k -b cookies.txt -L -i -w '\n' -X POST https://xtc-platform.localhost.xqiz.it/host/shutdown
```

If you do not stop the server cleanly, the next start-up will be much slower, since the databases on the server will
need to be recovered.

### Third Part Installation Dependencies

Previously, to build and run, we required that NodeJS, NPM and Yarn were installed, and available in the
environment and PATH on the system where you execute the platform build and/or run. This is problematic 
since you may have several different applications that you work on that require different versions of
the software. It's problematic to have to switch between different versions of an external software
installation, and there are even meta-frameworks like NVM to do that, but it adds complexity, and
it's hard to always detect that you are running the right version.

It is even more problematic if you have to install or configure  the dependent software with root/admin
privileges, since this alters the global state of your development machine, perhaps breaking something
else you need to work on as well.

Luckily, this is 2024, and it's industry best practice to keep exactly versioned dependencies referenced
and resolvable inside the scope of a project. For those dependencies that still have to live as installed 
system executables, we containerize.

For the Platform, you don't need to install any additional software as long as you have a bootstrap
Java runtime for the Gradle wrapper. The Platform project will make sure that it downloads and uses
the correct and tested versions of its external dependencies. This includes NodeJS and all the other
things required to build the frontend. The build will always resolve and execute a specific version 
of an artifact, without any need for configuration. The build will always override any system
installation of its dependencies with its own, of a known and tested version and configuration.

#### Quasar

While the default behavior is to only install external software dependency at the XTC platform project repo
level, and in the system Gradle caches, e.g. under $GRADLE_USER_HOME/..., Quasar may still be installed by
the build as a "global" scope Node application. This should not be necessary for basic use cases, but since
previous XTC Platform repository supported this option, and we strive to preserve exact semantics of a
build or system, even when performing large changes, it is supported by the build, through the property:

```
   org.lang.platform.quasarGlobal=[true|false] 
```

If the property is not defined, it will default to "false".

As with all other Gradle properties, the installation mode for Quasar can be declared on the Gradle wrapper
command line, or in a gradle.properties file in the root of the repository, or under your GRADLE_USER_HOME
directory.

## License

The license for source code is Apache 2.0, unless explicitly noted. We chose Apache 2.0 for its
compatibility with almost every reasonable use, and its compatibility with almost every license,
reasonable or otherwise.

The license for documentation (including any the embedded markdown API documentation and/or
derivative forms thereof) is Creative Commons CC-BY-4.0, unless explicitly noted.

To help ensure clean IP (which will help us keep this project free and open source), pull requests
for source code changes require a signed contributor agreement to be submitted in advance. We use
the Apache contributor model agreements (modified to identify this specific project), which can be
found in the [license](./license) directory. Contributors are required to sign and submit an Ecstasy
Project Individual Contributor License Agreement (ICLA), or be a named employee on an Ecstasy
Project Corporate Contributor License Agreement (CCLA), both derived directly from the Apache
agreements of the same name. (Sorry for the paper-work! We hate it, too!)

The Ecstasy name is a trademark owned and administered by The Ecstasy Project. Unlicensed use of the
Ecstasy trademark is prohibited and will constitute infringement.

The xqiz.it name is a trademark owned and administered by Xqizit Incorporated. Unlicensed use of the
xqiz.it trademark is prohibited and will constitute infringement.

All content of the project not covered by the above terms is probably an accident that we need to be
made aware of, and remains (c) The Ecstasy Project, all rights reserved.
