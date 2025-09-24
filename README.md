# Platform as a Service #

This is the public repository for the open source Ecstasy PaaS project, sponsored by [xqiz.it](http://xqiz.it).

## Status:

This project is being actively developed, but is not yet considered a production-ready release.

## Layout

The project is organized as a number of sub-projects, with the important ones to know about being:

* The *common* library (`./common`), contains common interfaces shared across platform modules. 
  
* The *kernel* library (`./kernel`), contains the boot-strapping functionality. It's responsible for starting system services and introducing them to each other. 
  
* The *host* library (`./host`), contains the manager for hosted applications.

* The *platformDB* library (`./platformDB`), contains the platform database. 

* The *platformUI* library (`./platformUI`), contains the end-points for the platform web-application. 
  
## Installation

1. Please follow steps 1-3 of the [XDK Installation](https://github.com/xtclang/xvm#installation).
2. Clone [the platform repository](https://github.com/xtclang/platform) to your local machine. For purposes of this document, we will assume that the project directory is `~/Development/platform/`, but you may use whatever location makes sense for your environment.

## Steps to test the PAAS functionality:

Note that steps 2 and 3 are temporary, and step 3 needs to be re-executed every time after an OS reboot.

1. Create "xqiz.it" subdirectory under the user home directory for the platform persistent data. The subdirectory "platform" will be used to keep the platform operational information and subdirectory "users" for hosted applications.

2. Create a file "~/xqiz.it/platform/port-forwarding.conf" with the following content:

       rdr pass on lo0 inet proto tcp from any to self port 80  -> 127.0.0.1 port 8080
       rdr pass on lo0 inet proto tcp from any to self port 443 -> 127.0.0.1 port 8090

3. Run the following command to redirect http and https traffic to unprivileged ports:
      
       sudo pfctl -evf ~/xqiz.it/platform/port-forwarding.conf

4. Make sure you can ping the local platform address:
       
       ping xtc-platform.localhost.xqiz.it
                                           
   The domain name `xtc-platform.localhost.xqiz.it` should resolve to `127.0.0.1`. This allows the same xqiz.it cloud-hosted platform to be self-hosted on the `localhost` loop-back address, enabling local and disconnected development.

   If that address fails to resolve you may need to change the rules on you DNS server. For example, for Verizon routers you would need add an exception entry for "127.0.0.1" to your DNS Server settings: "Exceptions to DNS Rebind Protection" (Advanced - Network Settings - DNS Server)   

5. Make sure you have the latest [gradle](https://gradle.org/), [node](https://nodejs.org/en), [yarn](https://yarnpkg.com/) and  [xdk-latest](https://github.com/xtclang/xvm#readme) installed. If you are using `brew`, you can simply say: 
        
        brew install gradle node yarn  

6. Change your directory to the `./platformUI/gui` directory inside the local git repo installed above.

        cd ~/Development/platform/platformUI/gui

7. Make sure all necessary *node* modules are installed within that directory using the following command:

        yarn install

8. If you plan to use `quasar` dev environment, please install it globally by the following command:

        npm install -g @quasar/cli
 
9. Build the platform services using the gradle command (from within the "platform" directory):

       cd ~/Development/platform/
       gradle clean build

10. Start the platform using the command (from within the "platform" directory):

        xec -L lib/ lib/kernel.xtc [password]

    Note: The password you choose during the very first run will be used to encrypt the platform key storage. You will need the same password for all subsequent runs.  

11. Open the [locally hosted platform web page](https://xtc-platform.localhost.xqiz.it): 

        https://xtc-platform.localhost.xqiz.it

    Note: Using the locally-created (self-signed) certificate from step 5 above, you will receive warnings from the browser about the unverifiability of the website and its certificate.

12. Follow the instructions from the [Examples](https://github.com/xtclang/examples) repository to build and "upload" a web application.

13. Log into the "Ecstasy Cloud" platform using the pre-defined test user "admin" and the password "password".

14. Go to the "Modules" panel and install any of the example module (e.g. "welcome.examples.org").

15. Go to the "Application" panel, register a deployment (e.g. "welcome") and "start" it  

16. Click on the URL to launch your application web page.

17. To control the hosting platform via the command line interface (CLI), start the command line tool:
    
    xec -L lib platformCLI.xqiz.it https://xtc-platform.localhost.xqiz.it admin:[password]

    Type "help" to see all available commands.

18. To stop the server cleanly, use a CLI "shutdown" command or from a separate shell run this:

        curl -k -b cookies.txt -L -i -w '\n' -X POST https://xtc-platform.localhost.xqiz.it/host/shutdown

    If you do not stop the server cleanly, the next start-up will be much slower, since the databases on the server will need to be recovered.

## PAAS in Docker #
> NOTE: Running the PAAS in Docker does NOT require port-forwarding as described above.
> In fact port-forwarding must be disabled/removed.

### Build
Simply run
```shell
docker build --no-cache -t xtc_platform .
```
The build pulls the latest xvm repo from github and uses this repo for the PAAS. The image is named **xtc_platform**.

The final image is about 724MB in size.

### Run
#### username:password
The PAAS requires a username and password to login.
* The default username is **admin**
* This password is passed in using **-e PASSWORD=[password]**.

#### PAAS configuration
The networking part of the PAAS is configured with a JSON formatted file named **cfg.json**.
The PAAS is looking for the config file inside the container at **~/xqiz.it/platform**. 
If a **cfg.json** is already present then it will be loaded and processed.
Otherwise it will be created from the default template which is here [cfg.json](./kernel/src/main/resources/cfg.json) .

Docker allows mapping a host folder into the container. This allows accessing the files created by the PAAS.
It is suggested to use the same location as if the PAAS is run locally on the machine. 
Create the local folder which will be mapped by Docker. 
```shell
mkdir -p ~/xqiz.it
```
If you want to make changes to **cfg.json** then start the PAAS once,
locate the config file, amend it and restart the container to pick up the changes.

#### Run it for the first time
```shell
docker run -e PASSWORD=[password] -p 80:8080 -p 443:8090 -v ~/xqiz.it:/root/xqiz.it --name xtc_platform xtc_platform
```

#### Restart
```shell
docker restart xtc_platform
```

#### Stop
```shell
docker stop xtc_platform
```

#### Teardown
Removing the container and the image in case they are not needed anymore
```shell
docker rm xtc_platform && docker rmi xtc_platform
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
agreements of the same name. (Sorry for the paper-work! We hate it, too!)

The Ecstasy name is a trademark owned and administered by The Ecstasy Project. Unlicensed use of the
Ecstasy trademark is prohibited and will constitute infringement.

The xqiz.it name is a trademark owned and administered by Xqizit Incorporated. Unlicensed use of the
xqiz.it trademark is prohibited and will constitute infringement.

All content of the project not covered by the above terms is probably an accident that we need to be
made aware of, and remains (c) The Ecstasy Project, all rights reserved.
