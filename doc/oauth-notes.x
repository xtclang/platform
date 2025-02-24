To allow a deployed application to use OAuth 2.0 with one of the supported `providers`, an
application deployers have to follow the outlined steps:

1. Choose one or more of providers to use:
    - apple (not fully tested)
    - amazon
    - github
    - google

2. Register a web application using the XTC platform, at which point a deployment name
    `deploymentName`` and URL `deploymentUrl` are established. For example, you one can deploy
    "count.example.org" module as "c1" under the url "https://c1.user.xqiz.it". Then you need to
    create a project (Github calls it "OAuth app" and Amazon calls it "security profile") with the
    corresponding provider at this site, where the first link points to creation process and
    the second - to modification of any attributes:

    - amazon:
        https://developer.amazon.com/loginwithamazon/console/site/lwa/create-security-profile.html
        https://developer.amazon.com/loginwithamazon/console/site/lwa/overview.html
    - github:
        https://github.com/settings/applications/new
        https://github.com/settings/developers
     - google:
        https://console.cloud.google.com/projectcreate
        https://console.cloud.google.com/auth/overview
    - apple: the process for Apple is more complicated and requires the application deployer to
             create a "brand" and request an access for the OAuth 2.0 API from Apple

    During the registration you would configure the attributes in a natural way, with only one
    requirement: the "callback" (or "return") URL would have to be set to:
        https://[deploymentURL}/.well-known/oauth/{provider}

    For example, the "c1" deployment above using "google" OAuth would require this callback URL:
        https://c1.user.xqiz.it/.well-known/oauth/google

3. Retrieve a "Client ID" and "Client Secret" from the OAuth provider and configure the OAuth
   provider for the XTC platform using the CLI command:
        set-auth-provider {deploymentName} {provider} {clientId} {clientSecret}

4. Add a link to your application landing page in the form of:

    https://[deploymentURL}/.well-known/oauth/login/{provider}/{redirectPath}

   Clicking on that link will perform user authentication with the specified provider and upon
   success will redirect the browser to the specified URL:

    https://[deploymentURL}/{redirectPath}