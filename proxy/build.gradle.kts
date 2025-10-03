/*
 * Build the "proxy manager" module.
 */

tasks.register("build") {
    dependsOn(project(":common").tasks["build"])

    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/proxy.x"

    commandLine("xcc",
                "-o", libDir,
                "-L", libDir,
                srcModule)
}