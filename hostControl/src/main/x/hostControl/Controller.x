import ecstasy.mgmt.Container;

import ecstasy.reflect.FileTemplate;

import common.ErrorLog;
import common.HostManager;
import common.WebHost;

import common.model.AccountInfo;
import common.model.ModuleInfo;

import web.Get;
import web.HttpStatus;
import web.PathParam;
import web.Post;
import web.Produces;
import web.QueryParam;
import web.WebServer;

@web.LoginRequired
@web.WebService("/host")
service Controller(HostManager mgr, WebServer webServer)
    {
    /**
     * The host manager.
     */
    private HostManager mgr;

    // TODO GG: temporary hack: it should be a session attribute or an argument, e.g.:
    //    @SessionParam("userId") String userId
    String accountName = "acme";

    @Get("/userId")
    String getUserId()
      {
      return accountName;
      }

    @Get("/registeredApps")
    ModuleInfo[] getRegistered()
        {
        if (AccountInfo info := mgr.getAccount(accountName))
            {
            return info.modules.values.toArray();
            }
        return [];
        }

    @Get("/availableModules")
    @Produces("application/json")
    String[] getAvailable()
      {
      if (Directory libDir := getUserHomeDirectory(accountName).findDir("lib"))
          {
          return libDir.names()
                       .filter(name -> name.endsWith(".xtc"))
                       .map(name -> name.slice(0..name.size-5))
                       .toArray(Constant);
          }
      return [];
      }

    @Post("/load")
    (HttpStatus, String) load(@QueryParam("app") String appName, @QueryParam String domain)
        {
        // there is one and only one application per [sub] domain
        if (mgr.getWebHost(domain))
            {
            return HttpStatus.OK, $"http://{domain}.xqiz.it:8080";
            }

        Directory userDir = getUserHomeDirectory(accountName);
        ErrorLog  errors  = new ErrorLog();

        if (WebHost webHost := mgr.createWebHost(userDir, appName, domain, errors))
            {
            try
                {
                webHost.container.invoke("createCatalog_", Tuple:(webHost.httpServer));

                assert AccountInfo info := mgr.getAccount(accountName);
                if (!info.modules.contains(appName))
                    {
                    mgr.storeAccount(info.addModule(new ModuleInfo(appName, WebApp, domain)));
                    }

                if (!errors.empty)
                    {
                    File consoleFile = webHost.homeDir.fileFor("console.log");
                    consoleFile.append(errors.toString().utf8());
                    }
                return HttpStatus.OK, $"http://{domain}.xqiz.it:8080";
                }
            catch (Exception e)
                {
                webHost.close(e);
                mgr.removeWebHost(webHost);
                errors.add($"Failed to initialize; reason={e.text}");
                }
            }
        return HttpStatus.NotFound, errors.toString();
        }

    @Get("/report/{domain}")
    @Produces("application/json")
    String report(@PathParam String domain)
        {
        String response;
        if (WebHost webHost := mgr.getWebHost(domain))
            {
            Container container = webHost.container;
            response = $"{container.status} {container.statusIndicator}";
            }
        else
            {
            response = "Not loaded";
            }
        return response.quoted();
        }

    @Post("/unload/{domain}")
    HttpStatus unload(@PathParam String domain)
        {
        if (WebHost webHost := mgr.getWebHost(domain))
            {
            mgr.removeWebHost(webHost);
            webHost.close();

            return HttpStatus.OK;
            }
        return HttpStatus.NotFound;
        }

    @Post("/unregister")
    HttpStatus unregister(@QueryParam("app") String appName, @QueryParam String domain)
        {
        unload(domain);

        assert AccountInfo info := mgr.getAccount(accountName);
        if (info.modules.contains(appName))
            {
            mgr.storeAccount(info.removeModule(appName));
            }
        return HttpStatus.OK;
        }

    @Post("/debug")
    HttpStatus debug()
        {
        // temporary; TODO: remove
        assert:debug;
        return HttpStatus.OK;
        }

    @Post("/shutdown")
    HttpStatus shutdown()
        {
        // TODO: only the admin can shutdown the host
        try
            {
            mgr.shutdown();
            }
        finally
            {
            callLater(() -> webServer.shutdown());
            }
        return HttpStatus.OK;
        }


    // ----- helpers -------------------------------------------------------------------------------

    /**
     * Get a user directory for the specified account.
     */
    private Directory getUserHomeDirectory(String account)
        {
        // temporary hack
        @Inject Directory homeDir;
        Directory accountDir = homeDir.dirFor($"xqiz.it/platform/{account}");
        accountDir.ensure();
        return accountDir;
        }
    }