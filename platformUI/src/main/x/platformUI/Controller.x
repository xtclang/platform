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
        try {
            hostManager.shutdown();
            accountManager.shutdown();
        } finally {
            callLater(ControllerConfig.shutdownServer);
        }
        return HttpStatus.OK;
    }
}