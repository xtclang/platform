import ecstasy.mgmt.Container;

import ecstasy.reflect.FileTemplate;

import common.WebHost;
import common.ErrorLog;
import common.HostManager;

import web.Consumes;
import web.Get;
import web.HttpStatus;
import web.PathParam;
import web.Post;
import web.Produces;
import web.QueryParam;
import web.WebServer;
import web.WebServer.Handler;

@web.LoginRequired
@web.WebService("/host")
service Controller(HostManager mgr)
    {
    /**
     * The host manager.
     */
    private HostManager mgr;

    // TODO GG: temporary hack: it should be a session attribute or an argument, e.g.:
    //    @SessionParam("userId") String userId
    String account = "acme";

    @Get("/userId")
    String getUserId()
      {
      return account;
      }

    @Get("/registeredApps")
    String getRegistered()
      {
      return "[]";
      }

    @Get("/availableModules")
    // @Produces("application/json") TODO GG: json mapping is not working for immutable Array<String>
    String getAvailable()
      {
      assert Directory libDir := getUserHomeDirectory(account).findDir("lib");
      String[] names = libDir.names()
                    .filter(name -> name.endsWith(".xtc"))
                    .map(name -> name.slice(0..name.size-5))
                    .toArray(Constant);

      StringBuffer buf = new StringBuffer(64);
      names.appendTo(buf, render = name -> name.quoted());
      return buf.toString();
      }

    @Post("/load")
    (HttpStatus, String) load(@QueryParam("app") String appName, @QueryParam String domain)
        {
        // there is one and only one application per [sub] domain
        if (mgr.getWebHost(domain))
            {
            return HttpStatus.OK, $"http://{domain}.xqiz.it:8080";
            }

        Directory userDir = getUserHomeDirectory(account);
        ErrorLog  errors  = new ErrorLog();

        if (WebHost webHost := mgr.createWebHost(userDir, appName, domain, errors))
            {
            try
                {
                webHost.container.invoke("createCatalog_", Tuple:(webHost.httpServer));

                return HttpStatus.OK, $"http://{domain}.xqiz.it:8080";
                }
            catch (Exception e)
                {
                webHost.close(e);
                mgr.removeWebHost(webHost);
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

    @Post("/debug")
    HttpStatus debug()
        {
        // temporary; TODO: remove
        assert:debug;
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