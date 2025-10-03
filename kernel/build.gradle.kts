/*
 * Build the "kernel" module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    dependsOn(project(":common")     .tasks["build"])
    dependsOn(project(":platformDB") .tasks["build"])

    val srcModule = "${projectDir}/src/main/x/kernel.x"

    commandLine("xcc", "--verbose",
                "-o", libDir,
                "-L", libDir,
                "-r", "${projectDir}/src/main/resources",
                srcModule)
}