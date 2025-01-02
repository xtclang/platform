/*
 * Build the "platformCLI" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/platformCLI.x"

    project.exec {
        commandLine("xcc",
            "-o", libDir,
            "-L", libDir,
            srcModule)
    }
}