/**
 * settings.gradle.kts is used for bootstrapping a build.
 *
 * This is based on the xtc-application-template repository, so understand how it works
 * and how to supply credentials. If you have put working GitHub credentials in your
 * $GRADLE_USER_HOME/gradle.properties already, this should just work.
 *
 * You will need properties named "gitHubUrl" , "gitHubUser" an "gitHubToken"
 * available to the system, in order for it to work. Please see the README.md
 * on how to set this up, and why you have to do this.
 */

pluginManagement {
    repositories {
        val mavenLocalRepo: String? by settings
        val xtclangGitHubRepo: String? by settings

        val gitHubUser: String? by settings
        val gitHubToken: String? by settings
        val gitHubUrl: String by settings

        println("Plugin: mavenLocal=$mavenLocalRepo, xtclangGitHubRepo=$xtclangGitHubRepo")
        if (mavenLocalRepo != "true" && xtclangGitHubRepo != "true") {
            throw GradleException("Error: either or both of mavenLocalRepo and xtclangGitHubRepo must be set.")
        }

        if (xtclangGitHubRepo == "true") {
            maven {
                url = uri(gitHubUrl)
                credentials {
                    username = gitHubUser
                    password = gitHubToken
                }
            }
        }

        if (mavenLocalRepo == "true") {
            // Define mavenLocal as an artifact repository (disabled by default)
            mavenLocal()
        }

        // Define Gradle Plugin Portal as a plugin repository
        gradlePluginPortal()
    }

    plugins {
        id("org.xtclang.xtc-plugin")
        id("com.github.node-gradle.node")
    }
}

@Suppress("UnstableApiUsage")
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // Define XTC org GitHub Maven as a plugin repository
        val mavenLocalRepo: String? by settings
        val xtclangGitHubRepo: String? by settings

        val gitHubUser: String? by settings
        val gitHubToken: String? by settings
        val gitHubUrl: String by settings

        println("Repos: mavenLocal=$mavenLocalRepo, xtclangGitHubRepo=$xtclangGitHubRepo")
        if (mavenLocalRepo != "true" && xtclangGitHubRepo != "true") {
            throw GradleException("Error: either or both of mavenResolveFromMavenLocal and mavenResolveFromXtcGitHub must be set.")
        }

        if (xtclangGitHubRepo == "true") {
            maven {
                url = uri(gitHubUrl)
                credentials {
                    username = gitHubUser
                    password = gitHubToken
                }
            }
        }

        if (mavenLocalRepo == "true") {
            // Define mavenLocal as an artifact repository (disabled by default)
            mavenLocal()
        }

        /**
         * Patch the Node configuration, so that the Node plugin doesn't try to add hardcoded
         * repositories to the Platform project during build. We are following the best-practice
         * of forbidding any repository declaration anywhere else but project settings. The Node
         * plugin does not. However, it's way more important to be able to specify an exact Node
         * version, and integrate that with the build, than having to fall back on a system wide
         * version of NodeJS that may or may not be installed on your machine, and may or may
         * not work well the Platform build. The Platform build religiously declares all its
         * required dependencies its repository, and SHOULD NEVER rely on any other system state
         * of its host machine. This also very easily paves the way for integration testing, CI/CD,
         * containerization and avoids contaminating your machine with multiple NodeJS versions.
         * In 2024, we do not install and rely on system wide software on a dev machine, unless
         * we are completely out of alternatives.
         *
         * For the NodeJS Gradle plugin, this is a known bug, and the workaround is the one
         * recommended by the plugin developers:
         * @see https://github.com/node-gradle/gradle-node-plugin/blob/main/docs/faq.md#is-this-plugin-compatible-with-centralized-repositories-declaration
         */
        ivy {
            name = "NodeJS"
            setUrl("https://nodejs.org/dist/")
            patternLayout {
                artifact("v[revision]/[artifact](-v[revision]-[classifier]).[ext]")
                ivy("v[revision]/ivy.xml")
            }
            metadataSources {
                artifact()
            }
            content {
                includeModule("org.nodejs", "node")
            }
        }
    }
}

// Set the name of the main project.
rootProject.name = "platform"

listOfNotNull(
    "kernel",
    "common",
    "host",
    "platformDB",
    "platformUI",
    "platformCLI"
).forEach {
    include(":$it")
    logger.info("[platform] Added subproject '$it' to build.")
}

