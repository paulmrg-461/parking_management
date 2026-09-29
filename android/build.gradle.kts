import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Plugin modules from pub ship their own (often ancient) compileSdk — e.g.
// bluetooth_print_plus declares 31. AGP 9 fails any library compiled below the
// API level its dependencies require, so lift legacy library modules to the
// same compile level Flutter uses for the app (36).
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") as? LibraryExtension
        if (android != null && (android.compileSdk ?: 0) < 36) {
            android.compileSdk = 36
        }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
