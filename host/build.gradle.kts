/*
 * Build the host module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn(project(":common").tasks["build"])

    doLast {
        val src = fileTree("${projectDir}/src").files.stream().
                mapToLong{f -> f.lastModified()}.max().orElse(0)
        val dst = file("$libDir/host.xtc").lastModified()

        if (src > dst) {
            val srcModule = "${projectDir}/src/main/x/host.x"

            project.exec {
                commandLine("xcc", "--verbose",
                            "-o", libDir,
                            "-L", libDir,
                            srcModule)
            }
        }
    }
}