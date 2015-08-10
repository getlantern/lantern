/**
 * Copyright 2015 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package org.golang.mobile

import org.junit.Test
import org.gradle.testfixtures.ProjectBuilder
import org.gradle.api.Project
import static org.junit.Assert.*

class GobindPluginTest {
    @Test
    public void gobindPluginAddsGobindTaskToProject() {
        Project project = ProjectBuilder.builder().build()
        project.apply plugin: 'org.golang.mobile.bind'

        assertTrue(project.tasks.gobind instanceof GobindTask)
    }
}
