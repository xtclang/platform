/*
 * Main build file for the "platform" project.
 */

group   = "platform.xqiz.it"
version = "0.1.0"

val host        = project(":host");
val hostControl = project(":hostControl");

val libDir = "${projectDir}/lib"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"
    delete(libDir)

    dependsOn(hostControl.tasks["clean"])
}

tasks.register<Copy>("updateXdk") {

    val xdkHome = "$projectDir/xdk/"

    var xvmHome = System.getProperty("xvm.home")
    if (xvmHome == null || xvmHome == "") {
        xvmHome = "../xvm"
    }
    val xdkExt = "$xvmHome/xdk/build/xdk"
    val xdkLib = "$projectDir/xdk"

    val src = fileTree(xdkExt).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dst = fileTree(xdkLib).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (src > dst) {
        from("$xdkExt") {
            include("**")
        }
        into(xdkLib)
        doLast {
            println("Finished task: updateXdk")
        }
    }
    else {
        println("Xdk is up to date")
    }
}

val build = tasks.register("build") {
    group       = "Build"
    description = "Build all"

    dependsOn(host       .tasks["build"])
    dependsOn(hostControl.tasks["build"])
}

tasks.register("run") {
    group       = "Run"
    description = "Run the platform"

    dependsOn(build)

    doLast {
        val libDir = "$rootDir/lib"

        project.exec {
            commandLine("xec",
                        "-L", "$libDir",
                        "$libDir/host.xtc")
        }
    }
}