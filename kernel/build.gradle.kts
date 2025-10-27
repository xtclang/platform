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

// Export processed cfg.json for distribution
val exportConfig by tasks.registering(Copy::class) {
    group = "distribution"
    description = "Export processed cfg.json for platform distribution"

    from(layout.buildDirectory.file("xtc/main/resources/cfg.json"))
    into(layout.buildDirectory.dir("dist"))

    dependsOn(tasks.processResources, tasks.processXtcResources)
}

// Create a consumable configuration for cfg.json
val cfgJsonElements by configurations.creating {
    isCanBeConsumed = true
    isCanBeResolved = false
    outgoing.artifact(exportConfig.map { it.outputs.files.singleFile })
}
