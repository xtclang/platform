/**
 * Unit tests for the stub WebApp's pure static helpers on [stub.Unavailable].
 *
 * Proof-of-concept for the platform xunit test lane: these call the service's
 * static functions directly (no service instance, no web server, no injection
 * context) and run under `./gradlew :stub:test` (and as part of `./gradlew build`).
 */
module StubTest {
    package stub import stub.xqiz.it;

    import stub.Unavailable;

    @Test
    void landingPathIsRootAndIndex() {
        assert Unavailable.isLandingPath("") as "the site root serves the landing page";
        assert Unavailable.isLandingPath("index.html") as "index.html serves the landing page";
    }

    @Test
    void otherPathsAreNotLanding() {
        assert !Unavailable.isLandingPath("app.js") as "an asset path is not the landing page";
        assert !Unavailable.isLandingPath("index.htm") as "a near-miss is not the landing page";
        assert !Unavailable.isLandingPath("Index.html") as "matching is case-sensitive";
    }

    @Test
    void applyTagsSubstitutesEachPlaceholder() {
        String out = Unavailable.applyTags("Deployment %deployment% on %host%",
                                           ["%deployment%"="acme", "%host%"="node1"]);
        assert out == "Deployment acme on node1" as "every placeholder is replaced with its value";
    }

    @Test
    void applyTagsLeavesUnmatchedTemplateUnchanged() {
        String template = "<html>no placeholders here</html>";
        assert Unavailable.applyTags(template, ["%missing%"="x"]) == template
                as "replacing an absent placeholder changes nothing";
    }
}
