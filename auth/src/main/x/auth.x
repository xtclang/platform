/**
 * This module contains an REST API endpoint that provides user authentication management
 * functionality to web applications that are hosted on the platform.
 *
 * Additionally, it contains a command line tool that communicates with the [UserEndpoint] web
 * service. To run it, use the following command:
 *
 *      xec auth.xqiz.it [server URI]
 */
@webcli.TerminalApp("User Authentication Management Tool", "auth> ", auth=Password)
module auth.xqiz.it {
    package convert import convert.xtclang.org;
    package json    import json.xtclang.org;
    package sec     import sec.xtclang.org;
    package web     import web.xtclang.org;
    package webauth import webauth.xtclang.org;
    package webcli  import webcli.xtclang.org;
}