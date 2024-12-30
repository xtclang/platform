/*
 * Build the "githubCLI" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/githubCLI.x"

    project.exec {
        commandLine("xcc", "-o", libDir, srcModule)
    }
}