/*
 * Build the "host controller" module.
 */

tasks.register("compile") {
    group       = "Build"
    description = "Compile this module"

    val srcModule = "${projectDir}/src/main/x/hostControl.x"
    val rootDir   = "${rootProject.rootDir}"
    val libDir    = "$rootDir/lib"

    project.exec {
        commandLine("xtc", "-verbose",
                    "-o", "$libDir",
                    "-L", "$libDir",
                    "$srcModule")
    }
}