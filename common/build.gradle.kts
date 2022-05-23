/*
 * Build the "common" module.
 */

val xdkExe = "${rootProject.projectDir}/xdk/bin"

tasks.register("compile") {
    group       = "Build"
    description = "Compile this module"

    val srcModule = "${projectDir}/src/main/x/common.x"
    val rootDir   = "${rootProject.rootDir}"
    val libDir    = "$rootDir/lib"

    project.exec {
        commandLine("$xdkExe/xtc", "-verbose",
                    "-o", "$libDir",
                    "$srcModule")
    }
}