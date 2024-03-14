/**
 * Main build file for the "platform" project.
 */
import org.xtclang.plugin.tasks.XtcCompileTask
import org.xtclang.plugin.tasks.XtcRunTask

/**
 * Enable the XTC plugin, so that we can parse this build file. In the interest to avoid
 * hardcoded artifact descriptors, and copy-and-paste for versions, we refer to the
 * plugin aliases declared in "gradle/libs.versions.toml"
 */
plugins {
    alias(libs.plugins.xtc)
    alias(libs.plugins.tasktree) // for debugging purposes.
}

/**
 * Dependencies to other projects, configurations and artifacts.
 *
 * These are the dependencies to other projects, and to the XDK proper (versioned). We follow
 * the Gradle Version Catalog standard for this project, and normally, when changing the version
 * of any requested artifact or plugin, there should only be the need to change
 * "gradle/libs.versions.toml"
 */
dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(project(":kernel")) // main module to run.
    xtcModule(project(":common"))      // runtime library path
    xtcModule(project(":host"))        // runtime library path
    xtcModule(project(":platformDB"))  // runtime library path
    xtcModule(project(":platformUI"))  // runtime library path
    xtcModule(project(":platformCLI")) // runtime library path
}

/**
 * Gather all compiled XTC modules from subprojects into a single location: $rootProject/build/platform.
 */
val commonXtcOutputDir = layout.buildDirectory.dir("platform")

allprojects {
    tasks.withType<XtcCompileTask>().configureEach {
        //outputs.dir(commonXtcOutputDir)
        doLast {
            copy {
                val compilerOutput = outputs.files.asFileTree
                compilerOutput.forEach {
                    logger.lifecycle("XTC module output: ${it.absolutePath} -> ${commonXtcOutputDir.get().asFile.absolutePath}")
                }
                from(compilerOutput)
                into(commonXtcOutputDir)
            }
        }
    }
}

/**
 * This is the run configuration, which configures all xtcRun taks for the main source set. (runXtc, runAllXtc)
 * The DSL for modules to run is a list of "module { }" elements or a list of moduleName("...") statements.
 * To look at the DSL for all parts of the XTC build, you can use your IDE and browse the implementing
 * classes. For example, there should be a hint in IntelliJ with the type for the xtcRun element and
 * the modules element (DefaultXtcRuntimeExtension and XtcRuntimeExtension.XtcRunModule, respectively).
 * It is a good way to understand how the build DSL works, so you can add your own powerful XTC build
 * syntax constructs and nice syntactic sugar/shorthand for things you feel should be simpler to write.
 */
xtcRun {
    debug = false // Set to true to get the launcher to pause and wait for a debugger to attach.
    verbose = true
    stdin = System.`in` // Prevent Gradle from eating stdin; make it interactive with the Gradle process that executes the kernel.
    module {
        moduleName = "kernel"
        moduleArg(passwordProvider)
        //findProperty("keystorePassword")?.also {
        //    moduleArg(it.toString())
        //}
    }
}

/**
 * Lazy password resolution provider.
 *
 * The password must support both:
 *
 *    1) Entering it on stdin when the platform kernel is getting started.
 *    2) Retrieve it from the environment as described below, or through
 *       similar methods. SUPPORTING THIS USE CASE IS ABSOLUTELY NECESSARY
 *       FOR AUTOMATIC CI/CD INTEGRATION (e.g. with GitLab/GitHub/TeamCity
 *       or other industrial strength integration testing frameworks.)
 *
 * Read the password. Typically, the password is either placed as a Gradle property
 * with the key "keystorePassword" in an external gradle.properties or init
 * file outside the project repository. The most common choice is
 * $GRADLE_USER_HOME/.gradle.properties, which generally contains secrets.
 *
 * You can also send values as project properties for the root project by using the
 * "-P" switch on the Gradle command line, like so:
 * "./gradlew run -PkeystorePassword=Uhlers0th"
 *
 * If you do not provide a password, i.e., defining that property from the command line
 * or a "*.properties" file, the XTC Platform will ask the user to input the password
 * from stdin. The default behavior if this happens from Gradle, is to show stdin from
 * the Gradle run process to the user and allow inputs there. (Or from the actual
 * execution command line, of course, if you do it manually).
 */

internal val passwordProvider: Provider<String> = provider {
    logger.lifecycle("Resolving password for XTC platform...")
    findProperty("keystorePassword")?.toString() ?: ""
}

/**
 * Run the XTC Platform. Note that this is a Gradle job, and as such gets is dependencies from the module path
 * in the Gradle plugin for all source in the project. It will use a module path precisely including
 * the correct dependencies.
 *
 * PLEASE Read the rest of this comment if you are interested how we can best model the architectural
 * support for the XTC Platform, and why.
 *
 * This is very neat, but of course we don't want to start a Gradle task to run the platform, as the task
 * never completes, given the standard operation. Thus, the more kludgy solution if you want to run the
 * project is the "classic" use-a-commandline-method.
 *
 * To derive a working command line, you can execute "./gradlew run --info" and look for "JavaExec" in the log.
 * Or you can do "XTC_PLUGIN_VERBOSE_PROPERTY=true ./gradlew run" for less info.
 *
 * Ongoing XTC Plugin improvements (TODO):
 *
 *   1) The ability to retrieve a complete self-contained command line from the XTCPlugin launcher tasks instead
 *   of having to scrape logs.
 *
 *   2) The ability explicitly ask the plugin for that command line, or at least programmatically represent
 *   it as part of an output configuration for the task.
 *
 *   2) Implement an XtcChildProcessLauncher that inherits the XtcLauncher interface. This would use the Java
 *   process builder to spawn the platform in the background instead of with JavaExec. That would give us
 *     2.1) A state where Gradle finishes and exists after the run task (and any cleanups after that), but
 *          leaves the platform running in the background.
 *     2.2) Still custom input and output stream configuration, so the log is not lost, and we get
 *          interactive mode with the created child process by just "foregrounding" it, when we need to.
 *
 *    Typically, these improvements make sense, as they follow the law of least astonishment for Docker Compose.
 *    The user would typically do "./gradlew build" (or install/distribution or any other bundling tasks
 *    that is required in the environment), followed by a "./gradlew up". This starts the platform in the background
 *    and the Gradle process goes away. To take the server down, we can execute "./gradlew down".
 *
 *    3) Touch op the existing Dockerfile, add a docker-compose.yaml, and provide the build and run
 *       semantics with docker-compose. Here we both have the avantage that we don't need to set up
 *       various things on our local machine, remember to run some "sudo" command very reboot, and so on.
 *       For the equivalent of ~/xqiz.it, it's trivial to add that very directory as a Docker volume
 *       in the compose script, or even better create a docker volume, that can be reused, closed, moved,
 *       suspended, aggregated with the Example apps in one virtual environment, and so on. This will
 *       be fundamental both for devleoping "examples" and other XTC platform applications, as well as
 *       the platform itself.
 */
tasks.withType<XtcRunTask>().configureEach {
    verbose = true
}

val run by tasks.registering {
    group = "application"
    description = "Build (if necessary) and run the platform (equivalent to 'xec [-L <module>]+ kernel.xtc <password>)"
    dependsOn(tasks.runXtc)
    doFirst {
        logger.lifecycle("Starting the XTC platform (kernel).")
    }
}
