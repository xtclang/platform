/*
 * Build the host module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    dependsOn(project(":common").tasks["build"])
    dependsOn(project(":stub").tasks["build"])

    val srcModule = "${projectDir}/src/main/x/host.x"

    commandLine("xcc", "--verbose",
            "-o", libDir,
            "-L", libDir,
            srcModule)
}