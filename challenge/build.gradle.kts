/*
 * Build the "challenge" module.
 */

tasks.register("build") {
    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    val libDir    = "${rootProject.projectDir}/lib"
    val srcModule = "${projectDir}/src/main/x/challenge.x"

    commandLine("xcc", "-o", libDir, srcModule)
}