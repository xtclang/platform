/*
 * Build the "kernel" module.
 */

plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(projects.auth)
    xtcModule(projects.common)
    xtcModule(projects.platformDB)
}

// Process cfg.json template with port overrides if set
tasks.named<ProcessResources>("processResources") {
    val httpPort = providers.gradleProperty("platform.httpPort")
    val httpsPort = providers.gradleProperty("platform.httpsPort")

    // Only filter cfg.json if we have port overrides
    if (httpPort.isPresent || httpsPort.isPresent) {
        filesMatching("cfg.json") {
            filter { line ->
                var result = line
                if (httpPort.isPresent && line.contains("\"httpPort\"")) {
                    result = "\"httpPort\":${httpPort.get()},"
                }
                if (httpsPort.isPresent && line.contains("\"httpsPort\"")) {
                    result = "\"httpsPort\":${httpsPort.get()},"
                }
                result
            }
        }
    }
}

val cfgJsonOriginal = file("src/main/resources/cfg.json")
val cfgJsonProcessed = layout.buildDirectory.file("xtc/main/resources/cfg.json")

tasks.compileXtc {
    // Restore original cfg.json timestamp right before compilation so the XTC
    // compiler embeds the correct (original) timestamp in the .xtc module.
    // This MUST be doFirst (not a separate task) to guarantee the timestamp is
    // set at the exact moment the compiler reads the file.
    doFirst {
        val originalTs = cfgJsonOriginal.lastModified()
        cfgJsonProcessed.get().asFile.let { if (it.exists()) it.setLastModified(originalTs) }
    }
}

// Expose processed cfg.json directly (no intermediate copy)
val cfgJsonElements by configurations.creating {
    isCanBeConsumed = true
    isCanBeResolved = false
    outgoing.artifact(cfgJsonProcessed) {
        builtBy(tasks.processXtcResources)
    }
}
