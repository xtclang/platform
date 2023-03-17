# Platform as a Service #

This is the public repository for the prototype of the PAAS project.

## What is PAAS?

TODO

## Status:

This project is currently in the "proof of concept" mode.

## License

TODO

## Layout

The project is organized as a number of sub-projects, with the important ones to know about being:

* The *common* library ([platform/common](./common)), contains common interfaces shared across platform modules. 
  
* The *kernel* library ([platform/kernel](./kernel)), contains the boot-strapping functionality. It's responsible for starting system services and introducing them to each other. 
  
* The *host* library ([platform/host](./host)), contains the manager for hosted applications.

* The *platformDB* library ([platform/platformDB](./platformDB)), contains the platform database. 

* The *platformUI* library ([platform/platformUI](./platformUI)), contains the end-points for the platform web-application. 
  
## Steps to test the PAAS functionality

As a temporary process, do the following:

1. Make sure your "etc/hosts" file contains the following entries:

       127.0.0.10 admin.xqiz.it
       127.0.0.20 welcome.acme.user.xqiz.it
       127.0.0.21 banking.acme.user.xqiz.it

2. Allow the loopback addresses binding by running this script as an admin user: (this step needs to be repeated after reboot)

        cd platform
        sudo ./bin/allowLoopback.sh

3. Create "xqiz.it" subdirectory under the user home directory for the platform persistent data. The subdirectory "platform" will be used to keep the platform operational information and subdirectory "users" for hosted applications.

4. Create a self-signed certificate for the platform web server. For example:
   
       keytool -genkeypair -keyalg RSA -alias platform -keystore ~/xqiz.it/platform/certs.p12 -storetype PKCS12 -storepass [password] -validity 365 -keysize 2048 -dname "OU=Platform, O=[your name], C=US"

5. Start the platform services using the gradle command (from within the "platform" directory):

       gradle run

6. Open the hosting site in a browser: 

    http://admin.xqiz.it:8080/

7. Follow the instructions from the [Examples](https://github.com/xtclang/examples) repository to build and "upload" a web application.

8. Click "AddModule" and specify an application module and the domain ("welcome", or "banking").

9. Click "Load application" - after a couple of seconds a URL should appear.

10. Click on the URL to launch your application web page.