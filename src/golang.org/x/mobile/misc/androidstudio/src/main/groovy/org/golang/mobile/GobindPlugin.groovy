/*
 * Copyright 2015 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package org.golang.mobile

import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.Project
import org.gradle.api.Plugin
import org.gradle.api.Task
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction

import org.golang.mobile.OutputFileTask
import org.golang.mobile.AARPublishArtifact

/*
 * GobindPlugin configures the default project that builds .AAR file
 * from a go package, using gomobile bind command.
 * For gomobile bind command, see https://golang.org/x/mobile/cmd/gomobile
 */
class GobindPlugin implements Plugin<Project> {
    void apply(Project project) {
	project.configurations.create("default")
 	project.extensions.create('gobind', GobindExtension)

        Task gobindTask = project.tasks.create("gobind", GobindTask)
	gobindTask.outputFile = project.file(project.name+".aar")
	project.artifacts.add("default", new AARPublishArtifact(
		'mylib',
		null,
		gobindTask))

	Task cleanTask = project.tasks.create("clean", {
		project.delete(project.name+".aar")
	})
    }
}

class GobindTask extends DefaultTask implements OutputFileTask {
	@OutputFile
	File outputFile

	@TaskAction
	def gobind() {
	    def pkg = project.gobind.pkg.trim()
	    def gopath = project.gobind.GOPATH.trim()
	    def paths = project.gobind.PATH.trim() + File.pathSeparator + System.getenv("PATH")
	    if (!pkg || !gopath) {
		throw new GradleException('gobind.pkg and gobind.GOPATH must be set')
	    }
	    def gomobile = findGomobile()

	    Properties properties = new Properties()
	    properties.load(project.rootProject.file('local.properties').newDataInputStream())
	    def androidHome = properties.getProperty('sdk.dir')
	    if (!androidHome?.trim()) {
		// fallback to ANDROID_HOME
		androidHome = System.getenv("ANDROID_HOME")
	    }

            project.exec {
		executable(gomobile)

                args("bind", "-target=android", "-i", "-o", project.name+".aar", pkg)
		if (!androidHome?.trim()) {
			throw new GradleException('Neither sdk.dir or ANDROID_HOME is set')
		}
		environment("GOPATH", gopath)
		environment("PATH", paths)
		environment("ANDROID_HOME", androidHome)
	    }
        }

	def findGomobile() {
	    def gomobile = "gomobile"
	    if (System.getProperty("os.name").startsWith("Windows")) {
		gomobile = "gomobile.exe"
	    }
	    def paths = project.gobind.PATH + File.pathSeparator + System.getenv("PATH")
	    for (p in paths.split(File.pathSeparator)) {
		def f = new File(p + File.separator + gomobile)
		if (f.exists()) {
			return p + File.separator + gomobile
		}
	    }
	    throw new GradleException('failed to find gomobile command from ' + paths)
	}
}

class GobindExtension {
    // Package to bind.
    def String pkg = ""

    // GOPATH: necessary for gomobile tool.
    def String GOPATH = System.getenv("GOPATH")

    // PATH: must include path to 'gomobile' and 'go' binary.
    def String PATH = ""
}
