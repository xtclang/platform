/*
 * Build the "platformUI" module.
 */

val common = project(":common");

val libDir = "${rootProject.projectDir}/lib"

val webContent = "${projectDir}/src/main/resources/gui"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete("$projectDir/gui/build")
    delete("$projectDir/src/main/resources/gui")
}

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    dependsOn(common.tasks["build"])
    dependsOn(buildGui)

    doLast {
        val src = fileTree("${projectDir}/src").getFiles().stream().
                mapToLong({f -> f.lastModified()}).max().orElse(0)
        val dst = file("$libDir/platformUI.xtc").lastModified()

        if (src > dst) {
            val srcModule = "${projectDir}/src/main/x/platformUI.x"

            project.exec {
                commandLine("xtc", "-verbose", "-rebuild",
                            "-o", "$libDir",
                            "-L", "$libDir",
                            "$srcModule")
            }
        }
    }
}

val buildGui = tasks.register("buildGui") {
    group       = "Build"
    description = "Build the web app content"

    val src1 = fileTree("$projectDir/gui/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val src2 = fileTree("$projectDir/gui/public").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dest = fileTree("$webContent").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (src1 > dest || src2 > dest) {
        dependsOn(copyContent)
        }
    else {
        println("$webContent is up to date")
        }
}

val copyContent = tasks.register("copyContent") {

    val guiDir   = "$projectDir/gui"
    val guiBuild = "$guiDir/build"

    project.exec {
        workingDir(guiDir)
        commandLine("npm", "run", "build")
    }

    doLast {
        println("Copying static content from $guiBuild to $webContent")

        copy {
            from(guiBuild)
            into(webContent)
        }
    }
}