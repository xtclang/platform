# Platform as a Service in Docker #
> NOTE: Running the PAAS in Docker does NOT require port-forwarding as described in the **README.md**.
> In fact port-forwarding must be disabled/removed.

This folder contains extra files used to build and run the PAAS in a Docker container.
Follow these steps to build and run the PAAS within a container:
## build
cd into the repo's root folder and run
```shell
docker build --no-cache -t xtc_platform .
```
The build pulls the latest xvm repo from github and uses this checked out platform repo. The image is named **xtc_platform**.

The final image is about 724MB in size.
## run
### username:password
The PAAS requires a username and password to login.
* The default username is **admin**
* This password is passed in using **-e ADMIN_PASSWORD="a password"**.
### PAAS configuration
The networking part of the PAAS is configured with a JSON formatted file named **cfg.json**.
The PAAS is looking for the config file in ./docker/xqiz.it 
The default config is in [cfg.json](../kernel/src/main/resources/cfg.json)
If you want to make changes then copy the default one into ./docker/xqiz.it and amend it accordingly.
```shell
docker run -e ADMIN_PASSWORD="p455w0rd" \
       -p 80:8080 -p 443:8090  \
       -v ./docker/xqiz.it:/root/xqiz.it \
       --name xtc_platform \
       xtc_platform
```
## access the PAAS
Use the browser to access the PAAS e.g. https://xtc-platform.localhost.xqiz.it
