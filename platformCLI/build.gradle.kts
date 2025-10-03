/*
 * Build the "platformCLI" module.
 */

tasks.register("build") {
    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/platformCLI.x"

    commandLine("xcc",
        "-o", libDir,
        "-L", libDir,
        srcModule)
}