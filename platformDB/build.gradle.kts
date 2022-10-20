/*
 * Build the platformDB module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    doLast {
        val src = fileTree("${projectDir}/src").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dst = file("$libDir/platformDB.xtc").lastModified()

        if (src > dst) {
            val srcModule = "${projectDir}/src/main/x/platformDB.x"

            project.exec {
                commandLine("xtc", "-verbose",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
    }
}