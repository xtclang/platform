/*
 * Build the "stub" module.
 */

tasks.register("build") {
    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/stub.x"

    commandLine("xcc",
        "-o", libDir,
        "-r", "${projectDir}/src/main/resources",
        srcModule)
}