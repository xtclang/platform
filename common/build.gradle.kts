/*
 * Build the "common" module.
 */
tasks.register("compile") {
    group       = "Build"
    description = "Compile this module"

    val srcModule = "${projectDir}/src/main/x/common.x"
    val rootDir   = "${rootProject.rootDir}"
    val libDir    = "$rootDir/lib"

    project.exec {
        commandLine("xtc", "-verbose",
                    "-o", "$libDir",
                    "$srcModule")
    }
}