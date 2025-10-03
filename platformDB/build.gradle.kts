/*
 * Build the platformDB module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    dependsOn(project(":common").tasks["build"])

    val srcModule = "${projectDir}/src/main/x/platformDB.x"

    commandLine("xcc", "--verbose",
                "-o", libDir,
                "-L", libDir,
                srcModule)
}