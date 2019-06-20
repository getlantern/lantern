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
		def gopath = (project.gobind.GOPATH ?: System.getenv("GOPATH"))?.trim()
		if (!pkg || !gopath) {
			throw new GradleException('gobind.pkg and gobind.GOPATH must be set')
		}

		def paths = (gopath.split(File.pathSeparator).collect{ "$it/bin" } +
			System.getenv("PATH").split(File.pathSeparator)).flatten()
		// Default installation path of go distribution.
		if (isWindows()) {
			paths = paths + "c:\\Go\\bin"
		} else {
			paths = paths + "/usr/local/go/bin"
		}

		def gomobile = (project.gobind.GOMOBILE ?: findExecutable("gomobile", paths))?.trim()
		def gobin = (project.gobind.GO ?: findExecutable("go", paths))?.trim()
		def gomobileFlags = project.gobind.GOMOBILEFLAGS?.trim()
		def goarch = project.gobind.GOARCH?.trim()

		if (!gomobile || !gobin) {
			throw new GradleException('failed to find gomobile/go tools. Set gobind.GOMOBILE and gobind.GO')
		}

		paths = [findDir(gomobile), findDir(gobin), paths].flatten()

		def androidHome = ""
		try {
			Properties properties = new Properties()
			properties.load(project.rootProject.file('local.properties').newDataInputStream())
			androidHome = properties.getProperty('sdk.dir')
		} catch (all) {
			logger.info("failed to load local.properties.")
		}
		if (!androidHome?.trim()) {
			// fallback to ANDROID_HOME
			androidHome = System.getenv("ANDROID_HOME")
		}

		project.exec {
			executable(gomobile)

			def cmd = ["bind", "-i", "-o", project.name+".aar", "-target"]
			if (goarch) {
				cmd = cmd+goarch.split(" ").collect{ 'android/'+it }.join(",")
			} else {
				cmd << "android"
			}
			if (gomobileFlags) {
				cmd.addAll(gomobileFlags.split(" "))
			}
			cmd.addAll(pkg.split(" "))

			args(cmd)
			if (!androidHome?.trim()) {
				throw new GradleException('Neither sdk.dir or ANDROID_HOME is set')
			}
			environment("GOPATH", gopath)
			environment("PATH", paths.join(File.pathSeparator))
			environment("ANDROID_HOME", androidHome)
		}
	}

	def isWindows() {
		return System.getProperty("os.name").startsWith("Windows")
	}

	def findExecutable(String name, ArrayList<String> paths) {
		if (isWindows() && !name.endsWith(".exe")) {
			name = name + ".exe"
		}
		for (p in paths) {
		   def f = new File(p + File.separator + name)
		   if (f.exists()) {
			   return p + File.separator + name
		   }
		}
		throw new GradleException('binary ' + name + ' is not found in $PATH (' + paths + ')')
	}

	def findDir(String binpath) {
		if (!binpath) {
			return ""
		}

		def f = new File(binpath)
		return f.getParentFile().getAbsolutePath();
	}
}

class GobindExtension {
	// Package to bind. Separate multiple packages with spaces. (required)
	def String pkg = ""

	// GOPATH: necessary for gomobile tool. (required)
	def String GOPATH = System.getenv("GOPATH")

	// GOARCH: (List of) GOARCH to include.
	def String GOARCH = ""

	// GO: path to go tool. (can omit if 'go' is in the paths visible by Android Studio)
	def String GO = ""

	// GOMOBILE: path to gomobile binary. (can omit if 'gomobile' is under GOPATH)
	def String GOMOBILE = ""

	// GOMOBILEFLAGS: extra flags to be passed to gomobile command. (optional)
	def String GOMOBILEFLAGS = ""
}
