/**
 * Unit tests for the stub WebApp's pure helpers ([StubContent]).
 *
 * Proof-of-concept for the platform xunit test lane: these run under
 * `./gradlew :stub:test` (and as part of `./gradlew build`) with no web server
 * or injection context required.
 */
module StubTest {
    package stub import stub.xqiz.it;

    import stub.StubContent;

    @Test
    void landingPathIsRootAndIndex() {
        assert StubContent.isLandingPath("") as "the site root serves the landing page";
        assert StubContent.isLandingPath("index.html") as "index.html serves the landing page";
    }

    @Test
    void otherPathsAreNotLanding() {
        assert !StubContent.isLandingPath("app.js") as "an asset path is not the landing page";
        assert !StubContent.isLandingPath("index.htm") as "a near-miss is not the landing page";
        assert !StubContent.isLandingPath("Index.html") as "matching is case-sensitive";
    }

    @Test
    void applyTagsSubstitutesEachPlaceholder() {
        String out = StubContent.applyTags("Deployment %deployment% on %host%",
                                           ["%deployment%"="acme", "%host%"="node1"]);
        assert out == "Deployment acme on node1" as "every placeholder is replaced with its value";
    }

    @Test
    void applyTagsLeavesUnmatchedTemplateUnchanged() {
        String template = "<html>no placeholders here</html>";
        assert StubContent.applyTags(template, ["%missing%"="x"]) == template
                as "replacing an absent placeholder changes nothing";
    }
}
