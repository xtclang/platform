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

    val userHome = System.getProperty("user.home")

    // clean up the "platform" lib
    val platformDir = "$userHome/xqiz.it/platform"
    delete("$platformDir/build")

    // clean up the "acme" account lib
    val usersDir = "$userHome/xqiz.it/users"
    val account  = "acme"
    delete("$usersDir/$account/build")
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(project(":kernel")    .tasks["build"])
    dependsOn(project(":host")      .tasks["build"])
    dependsOn(project(":platformDB").tasks["build"])
    dependsOn(project(":platformDB2").tasks["build"])
    dependsOn(project(":platformUI").tasks["build"])
}

tasks.register("run") {
    group       = "Run"
    description = "Run the platform"

    dependsOn(build)

    doLast {
        println("Please run the platform directly using the following command:")
        println("   xec -L lib/ lib/kernel.xtc [password]")
    }
}