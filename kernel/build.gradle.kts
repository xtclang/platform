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

// Restore original timestamp after processing so the kernel doesn't see it as "newer"
// Uses Exec (touch -r) instead of doLast lambda for configuration cache compatibility
val preserveCfgJsonTimestamp by tasks.registering(Exec::class) {
    dependsOn(tasks.processXtcResources)
    commandLine("touch", "-r", cfgJsonOriginal.absolutePath, cfgJsonProcessed.get().asFile.absolutePath)
}

// Ensure compileXtc sees the correct timestamp
tasks.compileXtc {
    dependsOn(preserveCfgJsonTimestamp)
}

// Expose processed cfg.json directly (no intermediate copy)
val cfgJsonElements by configurations.creating {
    isCanBeConsumed = true
    isCanBeResolved = false
    outgoing.artifact(cfgJsonProcessed) {
        builtBy(preserveCfgJsonTimestamp)
    }
}
