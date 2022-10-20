/*
 * Main build file for the "platform" project.
 */

group   = "platform.xqiz.it"
version = "0.1.0"

val kernel     = project(":kernel");
val platformDB = project(":platformDB");

val libDir = "${projectDir}/lib"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"
    delete(libDir)
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(kernel    .tasks["build"])
    dependsOn(platformDB.tasks["build"])
}

tasks.register("run") {
    group       = "Run"
    description = "Run the platform"

    dependsOn(build)

    doLast {
        val libDir = "$rootDir/lib"

        project.exec {
            commandLine("xec",
                        "-L", "$libDir",
                        "$libDir/kernel.xtc")
        }
    }
}