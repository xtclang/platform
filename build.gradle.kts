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
