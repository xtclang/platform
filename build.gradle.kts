/*
 * Root build file for the "platform" project.
 */

plugins {
    alias(libs.plugins.xtc)
}

group = "platform.xqiz.it"

// Extract version catalog values for clarity (configuration-time safe)
val javaLanguageVersion = libs.versions.java.get().toInt()
val xtcPluginId = libs.plugins.xtc.get().pluginId

// Platform configuration - single source of truth (configuration-cache safe)
val platformHttpPort = providers.gradleProperty("platform.httpPort").orElse("8080")
val platformHttpsPort = providers.gradleProperty("platform.httpsPort").orElse("8090")

subprojects {
    group = rootProject.group
    version = rootProject.version

    // Apply Java toolchain configuration to all subprojects
    plugins.withType<JavaPlugin> {
        configure<JavaPluginExtension> {
            toolchain {
                languageVersion.set(JavaLanguageVersion.of(javaLanguageVersion))
            }
        }
    }

    // Apply XTC compile configuration to all subprojects
    pluginManager.withPlugin(xtcPluginId) {
        extensions.configure<org.xtclang.plugin.XtcCompilerExtension>("xtcCompile") {
            verbose = false
        }
    }
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

    from(configurations.xtcModule)
    into(layout.buildDirectory.dir("install/platform/lib"))
    // Copy cfg.json from kernel's exported configuration
    from(cfgJson) {
        into("..")
    }
}

xtcRun {
    verbose = true
    detach = true  // if this is executed from the install lifecycle, live on after the build has exited.
    modulePath.setFrom(layout.buildDirectory.dir("install/platform/lib"))
    module {
        moduleName = "kernel.xqiz.it"
        moduleArg(providers.gradleProperty("platform.password").orElse("password"))
    }
}

tasks.runXtc.configure {
    dependsOn(installDist)
}

// Up task: install distribution and run the platform
// TODO: The server will be brought up and down with platformCLI calls, headlessly. Right now we use legacy methods, that will be replaced when the
//    xtc-plugin aware build system has been validated.
val up by tasks.registering {
    group = "application"
    description = "Start the platform in the background"
    dependsOn(tasks.runXtc)
    doLast {
        logger.lifecycle("Platform started.")
    }
}

// Down task: shutdown the platform
// TODO: Migrate to use platformCLI shutdown command instead of curl for consistency with platform management
//  the curl method, while originally documented as a "hacky" way to shut down cleanly, will of course go away.
val down by tasks.registering(Exec::class) {
    group = "application"
    description = "Shutdown the running platform"

    // Capture providers at configuration time for configuration cache compatibility
    val httpsPort = platformHttpsPort

    // Use curl directly (cross-platform: works on Linux, macOS, and Windows)
    executable = "curl"

    argumentProviders.add {
        val port = httpsPort.get()
        listOf(
            "-k",
            "-f",           // Fail on HTTP errors (4xx, 5xx)
            "-s", "-S",     // Silent mode but show errors
            "-m", "10",     // 10 second timeout
            "--resolve", "xtc-platform.localhost.xqiz.it:$port:127.0.0.1",  // Required to xqiz.it DNS resolving localhost without a port number in the URL.
            "-H", "Host: xtc-platform.localhost.xqiz.it",
            "-X", "POST",
            "https://xtc-platform.localhost.xqiz.it:$port/host/shutdown"
        )
    }

    // Don't fail the task immediately on error, handle it ourselves
    isIgnoreExitValue = true

    doLast {
        val exitCode = executionResult.get().exitValue
        if (exitCode == 0) {
            logger.lifecycle("Platform shutdown command sent")
            return@doLast
        }
        val portValue = httpsPort.get()
        logger.error("""
Failed to shutdown the platform.
Possible reasons:
  - The platform is not currently running
  - The platform hasn't fully started yet and is not ready to accept connections
  - Connection timeout (check if the platform is responding at $portValue)
        """.trimIndent())
        throw GradleException("Platform shutdown failed (curl exit code: $exitCode)")
    }
}
