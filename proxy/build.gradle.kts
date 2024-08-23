/*
 * Build the "proxy manager" module.
 */

tasks.register("build") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/proxy.x"

    dependsOn(project(":common").tasks["build"])

    project.exec {
        commandLine("xcc",
                    "-o", libDir,
                    "-L", libDir,
                    srcModule)
    }
}