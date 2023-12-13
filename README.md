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
  
## Installation

1. Please follow steps 1-3 of the [XDK Installation](https://github.com/xtclang/xvm#installation).
2. Clone [the platform repository](https://github.com/xtclang/platform) to your local machine.

## Steps to test the PAAS functionality:

Note that steps 2 and 3 are temporary, and step 3 needs to be re-executed every time after an OS reboot.

1. Create "xqiz.it" subdirectory under the user home directory for the platform persistent data. The subdirectory "platform" will be used to keep the platform operational information and subdirectory "users" for hosted applications.

2. Create a file "~/xqiz.it/port-forwarding.conf" with the following content:

       rdr pass on lo0 inet proto tcp from any to self port 80  -> 127.0.0.1 port 8080
       rdr pass on lo0 inet proto tcp from any to self port 443 -> 127.0.0.1 port 8090

3. Run the following command to redirect http and https traffic to unprivileged ports:
      
       sudo pfctl -evf ~/xqiz.it/port-forwarding.conf

4. Create a self-signed certificate for the platform web server. For example:
   
        keytool -genkeypair -alias platform -keyalg RSA -keysize 2048 -validity 365 -dname "OU=Platform, O=[your name], C=US" -keystore ~/xqiz.it/platform/keystore.p12 -storetype PKCS12 -storepass [password]

5. Add a symmetric key to encode the cookies:

        keytool -genseckey -alias cookies -keyalg AES -keysize 256 -keystore ~/xqiz.it/platform/keystore.p12 -storetype PKCS12 -storepass [password]
   
6. Make sure you have the latest [gradle](https://gradle.org/), [node](https://nodejs.org/en), [yarn](https://yarnpkg.com/) and  [xdk-latest](https://github.com/xtclang/xvm#readme) installed. If you are using `brew`, you can simply say: 
        
       brew install gradle node yarn  

7. Make sure all necessary *node* modules are installed using the following command from the ([platform/platformUI/gui](./platformUI/gui)) directory:
   
        npm install

8. If you plan to use `quasar` dev environment, please intall it globally by the following command:

        npm install -g @quasar/cli
 
9. Build the platform services using the gradle command (from within the "platform" directory):

         gradle build

10. Start the platform using the command (from within the "platform" directory):

         xec -L lib/ lib/kernel.xtc [password]

11. Open the hosting site in a browser: 

         https://xtc-platform.localhost.xqiz.it

12. Follow the instructions from the [Examples](https://github.com/xtclang/examples) repository to build and "upload" a web application.
13. Log into the "Ecstasy Cloud" platform using "admin@acme.om/password" credentials.
14. Go to the "Modules" panel and install any of the example module (e.g. "welcome.examples.org").
15. Go to the "Application" panel, register a deployment (e.g. "welcome") and "start" it  
16. Click on the URL to launch your application web page.