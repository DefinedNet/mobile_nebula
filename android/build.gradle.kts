allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Redirect CMake's .cxx directory to the writable build directory.
    // Without this, plugins in read-only locations (e.g. Nix store) fail
    // because CMake tries to write .cxx/ inside the plugin source tree.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
            if (android.externalNativeBuild.cmake.path != null) {
                android.externalNativeBuild.cmake.buildStagingDirectory = newSubprojectBuildDir.asFile
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}