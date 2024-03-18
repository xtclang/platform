/*
 * Main build file for the "platform" project.
 */

group   = "platform.xqiz.it"
version = "0.1.0"

val libDir = "${projectDir}/lib"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"
    delete(libDir)
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(project(":kernel")     .tasks["build"])
    dependsOn(project(":host")       .tasks["build"])
    dependsOn(project(":platformDB") .tasks["build"])
    dependsOn(project(":platformUI") .tasks["build"])
    dependsOn(project(":platformCLI").tasks["build"])
}

tasks.register("run") {
    group       = "Run"
    description = "Run the platform"

    dependsOn(build)

    doLast {
        println("Please run the platform directly using the following command:")
        println("   xec -L lib/ kernel.xtc [password]")
    }
}