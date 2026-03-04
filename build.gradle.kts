/*
 * Root build file for the "platform" project.
 */

plugins {
    alias(libs.plugins.xtc)
}

group = "platform.xqiz.it"

subprojects {
    group = rootProject.group
    version = rootProject.version
}

// Configuration to consume cfg.json from kernel
val cfgJson by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true
}

dependencies {
    xdkDistribution(libs.xdk)

    // Declare all platform modules as xtcModule dependencies
    xtcModule(projects.auth)
    xtcModule(projects.stub)
    xtcModule(projects.challenge)
    xtcModule(projects.common)
    xtcModule(projects.githubCLI)
    xtcModule(projects.platformCLI)
    xtcModule(projects.proxy)
    xtcModule(projects.platformDB)
    xtcModule(projects.host)
    xtcModule(projects.kernel)
    xtcModule(projects.platformUI)

    // Consume cfg.json from kernel (using project() for configuration parameter)
    cfgJson(project(":kernel", configuration = "cfgJsonElements"))
}

// Assemble distribution from resolved xtcModule configuration
val installDist by tasks.registering(Copy::class) {
    group = "distribution"
    description = "Install platform modules to build/install/platform/lib for runtime"
    // We could reduce this to just depending on the configuration, but this is
    // like a "fence" for dependent artifact generation and provides deterministic builds
    dependsOn(tasks.build)
    // Configuration resolution automatically triggers builds of all xtcModule dependencies
    from(configurations.xtcModule)
    into(layout.buildDirectory.dir("install/platform/lib"))
    // Copy cfg.json from kernel's exported configuration
    from(cfgJson) {
        into("..")
    }
}
