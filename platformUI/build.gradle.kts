/*
 * Build the "platformUI" module.
 */

val libDir = "${rootProject.projectDir}/lib"

val guiDir     = "$projectDir/gui"
val webContent = "$guiDir/dist"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"

    delete(webContent)
}

tasks.register("build") {
    group       = "Build"
    description = "Build this module"

    // there must be a way to tell quasar not to rebuild if nothing changed, but I cannot
    // figure it out and have to use a manual timestamp check
    dependsOn(checkGui)
    dependsOn("compileXcc")
}

tasks.register<Exec>("compileXcc") {
    dependsOn(project(":common").tasks["build"])

    val srcModule = "${projectDir}/src/main/x/platformUI.x"

    commandLine("xcc", "--verbose",
                "-o", libDir,
                "-L", libDir,
                "-r", webContent,
                srcModule)
}

val checkGui = tasks.register("checkGui") {
    group       = "Build"
    description = "Build the web app content"

    val src1 = fileTree("$projectDir/gui/src").files.stream().
            mapToLong{f -> f.lastModified()}.max().orElse(0)
    val src2 = fileTree("$projectDir/gui/public").files.stream().
            mapToLong{f -> f.lastModified()}.max().orElse(0)
    val dest = fileTree(webContent).files.stream().
            mapToLong{f -> f.lastModified()}.max().orElse(0)

    if (src1 > dest || src2 > dest) {
        dependsOn(buildGui)
        }
    else {
        println("$webContent is up to date")
    }
}

val buildGui = tasks.register<Exec>("buildGui") {
    workingDir(guiDir)
    commandLine("yarn", "--ignore-engines", "quasar", "build")
}