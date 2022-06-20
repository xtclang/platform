/*
 * Build the hostDB module.
 */

val libDir = "${rootProject.projectDir}/lib"

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    doLast {
        val src = fileTree("${projectDir}/src").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dst = file("$libDir/hostDB.xtc").lastModified()

        if (src > dst) {
            val srcModule = "${projectDir}/src/main/x/hostDB.x"

            project.exec {
                commandLine("xtc", "-verbose",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
    }
}