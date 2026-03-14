allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.extra.set("compileSdkVersion", 36)
rootProject.extra.set("targetSdkVersion", 36)
rootProject.extra.set("minSdkVersion", 21)

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
