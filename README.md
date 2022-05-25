# Platform as a Service #

This is the public repository for the prototype of the PAAS project.

## What is PAAS?

TODO

## Status:

TODO

## License

TODO

## Layout

The project is organized as a number of sub-projects, with the important ones to know about being:

* The *common* library ([platform/common](./common)), contains common interfaces shared across 
  platform modules. 
  
* The *host* library ([platform/host](./host)), contains the host manager functionality. 
  
* The *hostControl* library ([platform/hostControl](./hostControl)), contains the end-points 
  for the platform web-application. 
  
## Steps to test the PAAS functionality

First, run start the host:

    gradle run

As a temporary step, upload any web application (see examples.welcome documentation)

Load the app, for example:

    curl -i -w '\n' -X POST http://admin.xqiz.it:8080/host/load -G -d 'app=welcome,domain=shop.acme.user'

Unload the app:

    curl -i -w '\n' -X POST http://admin.xqiz.it:8080/host/unload/shop.acme.user  