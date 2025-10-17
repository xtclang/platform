/*
 * Build the "platformUI" module.
 */

plugins {
    alias(libs.plugins.xtc)
    alias(libs.plugins.node)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(libs.versions.java.get().toInt()))
    }
}

dependencies {
    xdkDistribution(libs.xdk)
    xtcModule(project(":auth"))
    xtcModule(project(":common"))
}

xtcCompile {
    verbose = true
}

// Configure node-gradle plugin
node {
    download = true
    version = "22.11.0"
    npmVersion = "10.9.0"
    workDir = file("${project.projectDir}/.gradle/nodejs")
    npmWorkDir = file("${project.projectDir}/.gradle/npm")
    nodeProjectDir = file("${project.projectDir}/gui")
}

// Reference existing setup task
val yarnSetup by tasks.existing

// Install node modules
val yarnInstall by tasks.registering(com.github.gradle.node.yarn.task.YarnTask::class) {
    args = listOf("install", "--ignore-engines")
    workingDir = file("${project.projectDir}/gui")
    dependsOn(yarnSetup)
}

// Build GUI with Quasar
val buildGui by tasks.registering(com.github.gradle.node.yarn.task.YarnTask::class) {
    args = listOf("quasar", "build")
    workingDir = file("${project.projectDir}/gui")
    dependsOn(yarnInstall)

    inputs.dir("${project.projectDir}/gui/src")
    inputs.dir("${project.projectDir}/gui/public")
    inputs.file("${project.projectDir}/gui/package.json")
    outputs.dir("${project.projectDir}/gui/dist")
}

// Make XTC compilation depend on GUI build (resources)
val compileXtc by tasks.existing {
    dependsOn(buildGui)
}
