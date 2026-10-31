import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_webrtc 1.6.3 blocks Flutter's platform thread waiting for the first
// camera frame. That deadlocks with an incoming texture's EGL buffer queue.
subprojects {
    if (name == "flutter_webrtc") {
        val pluginManifest = projectDir.parentFile.resolve("pubspec.yaml").readText()
        check(Regex("(?m)^version: 1\\.6\\.3\\s*$").containsMatchIn(pluginManifest)) {
            "Review/remove the camera compatibility override when updating flutter_webrtc."
        }
        val compatSources = rootProject.fileTree("webrtc_compat") { include("*.java") }
        tasks.withType<JavaCompile>().configureEach {
            inputs.files(compatSources).withPropertyName("webrtcCompat")
            // AGP assigns its source providers after task configuration.
            doFirst { source(compatSources) }
            exclude {
                compatSources.files.any { compat ->
                    it.file.name == compat.name && it.file.canonicalFile != compat.canonicalFile
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
