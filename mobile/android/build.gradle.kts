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
}
subprojects {
    project.evaluationDependsOn(":app")
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    project.plugins.configureEach {
        if (this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin") || 
            this.javaClass.name.contains("com.android.build.gradle.AppPlugin")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null && android.namespace == null) {
                android.namespace = project.group.toString().ifEmpty { 
                    if (project.name.contains("razorpay")) "com.razorpay" else "com.finzo.fix.${project.name.replace("-", ".")}"
                }
            }
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.razorpay.com/repository/maven-releases/") }
    }
}
