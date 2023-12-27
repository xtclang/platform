import ecstasy.mgmt.Container;

import common.WebHost;

import web.*;

@WebService("/host")
service Controller
        extends CoreService {

    @Post("debug")
    @LoginOptional // TODO: remove
    HttpStatus debug() {
        assert:debug;
        return HttpStatus.OK;
    }

    @Post("shutdown")
    @LoginOptional // TODO: TEMPORARY: only the admin can shutdown the host
    HttpStatus shutdown() {
        if (!hostManager.shutdown()) {
            // wait a second (TODO: repeat a couple of times)
            @Inject Timer timer;
            timer.schedule(Second, hostManager.&shutdown(True));
            return HttpStatus.Processing;
        }
    accountManager.shutdown();
    httpServer.close();
    return HttpStatus.OK;
    }
}