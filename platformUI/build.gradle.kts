/*
 * Build the "platformUI" module.
 */

val common = project(":common")

val libDir = "${rootProject.projectDir}/lib"

val guiDir     = "${rootProject.projectDir}/../xqizit-spa"
val webContent = guiDir

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"
}

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn(common.tasks["build"])

    doLast {
        val srcModule = "${projectDir}/src/main/x/platformUI.x"

        project.exec {
            commandLine("xcc", "--verbose",
                        "-o", libDir,
                        "-L", libDir,
                        "-r", webContent,
                        srcModule)
        }
    }
}
