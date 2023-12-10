rootProject.name = "platform"

pluginManagement {
    repositories {
        mavenLocal()
        gradlePluginPortal() // This is used to resolve Node and other non-XTC related dependencies we need to build and run.
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
        mavenLocal()
        // TODO: May want to move this out into a specific node.workaround.settings.gradle.kts,
        //   or something, and apply that so that it just inlines here. Can't remember why
        //   that did not work on my first attempt.

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

listOfNotNull(
    "kernel",
    "common",
    "host",
    "platformDB",
    "platformUI"
).forEach {
    include(":$it")
    logger.lifecycle("Added subproject '$it' to build.")
}
