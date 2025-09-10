/*
 * Build the "common" module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn(project(":auth").tasks["build"])

    val src = fileTree("${projectDir}/src").files.stream().
            mapToLong{f -> f.lastModified()}.max().orElse(0)
    val dst = file("$libDir/common.xtc").lastModified()

    if (src > dst) {
        val srcModule = "${projectDir}/src/main/x/common.x"

        project.exec {
            commandLine("xcc", "--verbose",
                        "-o", libDir,
                        "-L", libDir,
                        "-r", "${projectDir}/src/main/resources",
                        srcModule)
        }
    }
}