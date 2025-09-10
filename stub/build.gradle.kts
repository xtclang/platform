/*
 * Build the "stub" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/stub.x"

    project.exec {
        commandLine("xcc",
            "-o", libDir,
            "-r", "${projectDir}/src/main/resources",
            srcModule)
    }
}