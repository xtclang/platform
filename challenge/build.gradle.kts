/*
 * Build the "challenge" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/challenge.x"

    project.exec {
        commandLine("xcc", "-o", libDir, srcModule)
    }
}