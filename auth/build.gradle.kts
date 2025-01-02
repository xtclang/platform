/*
 * Build the "auth" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/auth.x"

    project.exec {
        commandLine("xcc", "-o", libDir, srcModule)
    }
}