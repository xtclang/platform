/*
 * Main build file for the "platform" project.
 */

group = "org.xqiz.it"
version = "0.1.0"

val common      = project(":common");
val host        = project(":host");
val hostControl = project(":hostControl");

val libDir  = "${projectDir}/lib"

tasks.register("clean") {
    group       = "Build"
    description = "Delete previous build results"
    delete("$libDir")
}

tasks.register<Copy>("updateXdk") {

    val xdkHome = "$projectDir/xdk/"

    var xvmHome = System.getProperty("xvm.home")
    if (xvmHome == null || xvmHome == "") {
        xvmHome = "../xvm"
    }
    val xdkExt = "$xvmHome/xdk/build/xdk"
    val xdkLib = "$projectDir/xdk"

    val srcTimestamp = fileTree(xdkExt).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val dstTimestamp = fileTree(xdkLib).getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)

    if (srcTimestamp > dstTimestamp) {
        from("$xdkExt") {
            include("**")
        }
        into("$xdkLib")
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

    val commonSrc = fileTree("${common.projectDir}/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val commonDest = file("$libDir/common.xtc").lastModified()

    if (commonSrc > commonDest) {
        dependsOn(common.tasks["compile"])
        }

    val hostSrc = fileTree("${host.projectDir}/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val hostDest = file("$libDir/host.xtc").lastModified()

    if (hostSrc > hostDest) {
        dependsOn(host.tasks["compile"])
    }

    val hostCtrlSrc = fileTree("${hostControl.projectDir}/src").getFiles().stream().
            mapToLong({f -> f.lastModified()}).max().orElse(0)
    val hostCtrlDest = file("$libDir/hostControl.xtc").lastModified()

    if (hostCtrlSrc > hostCtrlDest) {
        dependsOn(hostControl.tasks["compile"])
    }
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