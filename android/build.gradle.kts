// android/build.gradle.kts (Raíz)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Eliminamos el bloque 'subprojects' que intentaba forzar namespaces, 
// ya que en Gradle 8.x esto causa conflictos con los plugins de Flutter.

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

