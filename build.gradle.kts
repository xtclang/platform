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

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(libs.versions.java.get().toInt()))
    }
}

dependencies {
    xdkDistribution(libs.xdk)

    // Declare all platform modules as xtcModule dependencies
    xtcModule(project(":auth"))
    xtcModule(project(":stub"))
    xtcModule(project(":challenge"))
    xtcModule(project(":common"))
    xtcModule(project(":githubCLI"))
    xtcModule(project(":platformCLI"))
    xtcModule(project(":proxy"))
    xtcModule(project(":platformDB"))
    xtcModule(project(":host"))
    xtcModule(project(":kernel"))
    xtcModule(project(":platformUI"))
}

// Assemble distribution from resolved xtcModule configuration
val installDist by tasks.registering(Copy::class) {
    group = "distribution"
    description = "Install platform modules to build/install/platform/lib for runtime"

    from(configurations.xtcModule)
    into(layout.buildDirectory.dir("install/platform/lib"))
}

// Configure platform runtime
xtcRun {
    verbose = true
    module {
        moduleName = "kernel"
        // Password can be provided via -PpasswordArg=yourpassword
        moduleArg(providers.gradleProperty("passwordArg").orElse("password"))
    }
}
