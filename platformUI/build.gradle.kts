/**
 * The platform UI subproject. This relies on npm and yarn for building the web
 * UI. We plug the node builder and the quasar runner into the Gradle lifecycle,
 * so that we don't need to rebuild the non-XTC parts of the webapp unless something
 * has explicitly changed.
 *
 * We also use the version catalog to resolve the name and version of the popular
 * third party Node plugin for Gradle.
 *
 * This project used to be buildable both with Npm and Yarn, but due to time
 * constraints, reimplementing the Npm functionality is in the backlog. The user
 * should not need to care anymore, however, because the build system takes care
 * of setting up the web app frameworks, and make sure they interact correctly
 * with the rest of the Gradle build lifecycle.
 */

import com.github.gradle.node.yarn.task.YarnTask

node {
    // Retrieve tested versions of Node, Npm and Yarn from the version catalog (see gradle/libs.versions.toml)
    version = libs.versions.node.get()
    npmVersion = libs.versions.npm.get()
    yarnVersion = libs.versions.yarn.get()

    // Download any Node, Npm and Yarn versions that aren't available locally, and use them from within the build.
    download = true
    // See settings.gradle.kts; workaround to make the Node plugin work, while still allowing repository declarations outside of settings.gradle.kts.
    distBaseUrl = null
}

plugins {
    alias(libs.plugins.node)
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(project(":common"))
}

// TODO: Future webapp improvement; implement a parallel NPM / package-lock based approach. Yarn does not like having a package lock in the same build.
internal val gui = project.file("gui")
internal val buildDirs = arrayOf("gui/node_modules", "gui/dist", "gui/.quasar")

/**
 * By adding the gui/dist folder as a resource directory, the build will also treat
 * it like an input to the build result. This means that any changes of its contents
 * or timestamps will require that we rebuild it and its dependencies. This also means
 * that as long as it stays unchanged, a finished build task for this project remains
 * a no-op.
 */
sourceSets.main {
    xtc {
        resources {
            srcDir(files("gui/dist/"))
        }
    }
}

val clean by tasks.existing {
    doLast {
        for (buildDir in buildDirs) {
            logger.info("Want to clean build dir: $buildDir")
            delete(layout.files(buildDir))
        }
    }
}

/**
 * Task that will make sure yarn updates all node_modules.
 */
val yarnAddDependencies by tasks.registering(YarnTask::class) {
    workingDir = gui
    dependsOn(tasks.yarnSetup)

    // Tag this task as a producer of the "node_modules" directory, implicitly ensuring that any changes
    // to the resolved node_modules will make its dependents rebuild properly.
    outputs.dir("gui/node_modules")

    // Add a dependency to quasar. If one exists in the yarn/lock file, it may be used instead, so
    // if the state of global/local installation changed, that may still rebuild, though, if it's
    // not installed in both places.
    val quasarGlobal = providers.gradleProperty("org.xtclang.platform.quasarGlobal")
    args = buildList {
        add("add")
        if (quasarGlobal.isPresent && quasarGlobal.get().toBoolean()) {
            add("global")
        }
        add("quasar")
        add("@quasar/cli")
    }

    doFirst {
        logger.lifecycle("Task '$name' installing Quasar (${if (quasarGlobal.isPresent && quasarGlobal.get().toBoolean()) "globally" else "locally, only for ${rootProject.name})"}.")
        printTaskInputsAndOutputs(LogLevel.INFO)
    }
}

/**
 * Task that defines the inputs and outputs for the Quasar webapp, and builds it. This means that the task
 * should detect, e.g. if someone changes index.html or a single Vue file, and then rerun the task. Otherwise
 * the task will be treated as "up to date".
 */
val yarnQuasarBuild by tasks.registering(YarnTask::class) {
    workingDir = gui
    dependsOn(yarnAddDependencies)

    inputs.files("gui/public")
    inputs.files("gui/index.html", "gui/src")
    outputs.dir("gui/.quasar")
    outputs.dir("gui/dist/spa") // Declare output file collection, even though empty, or we can never cache the yarnQuasarBuild task.
    args = listOf("quasar", "build")
    doLast {
        printTaskInputsAndOutputs(LogLevel.INFO)
    }
}

/**
 * Compile the XTC PlatformUI Module.
 */
val compileXtc by tasks.existing {
    dependsOn(verifySourceSets)
    dependsOn(yarnQuasarBuild)
}

val processResources by tasks.existing {
    dependsOn(yarnQuasarBuild)
}

val verifySourceSets by tasks.registering {
    dependsOn(processResources)
    mustRunAfter(yarnQuasarBuild)
    sourceSets.forEach {
        logger.info("*** Source Set: $it")
        it.resources.files.forEach {
            logger.info("** Resource: $it")
        }
    }
}

private fun Task.printTaskInputsAndOutputs(level: LogLevel = LogLevel.LIFECYCLE) {
    val inputFiles = inputs.files.asFileTree
    logger.log(level, "Inputs: $name: ${inputFiles.toList()}")
    val outputFiles = outputs.files.asFileTree
    logger.log(level, "Outputs: $name: ${outputFiles.toList()}")
    val ni = inputFiles.count()
    val no = outputFiles.count()
    logger.log(level, "${project.name} Task '$name' finished.")
    logger.log(level, "${project.name}     Inputs (count: $no):")
    inputs.files.asFileTree.forEachIndexed {
            i, it -> logger.log(level, "${project.name}     '$name' input $i (of $ni): $it")
    }
    logger.log(level, "${project.name}     Outputs (count: $no):")
    outputs.files.asFileTree.forEachIndexed {
            i, it -> logger.log(level, "${project.name}     '$name' output $i (of $no): $it")
    }
}
