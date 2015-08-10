/**
 * Copyright 2015 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package org.golang.mobile;

import org.golang.mobile.OutputFileTask;

import org.gradle.api.Task;
import org.gradle.api.artifacts.PublishArtifact;
import org.gradle.api.tasks.TaskDependency;

import java.io.File;
import java.util.Collections;
import java.util.Date;
import java.util.Set;

/**
 * custom implementation of PublishArtifact for published AAR
 */
public class AARPublishArtifact implements PublishArtifact {

    private final String name;
    private final String classifier;
    private final OutputFileTask task;
    private final TaskDependency taskDependency;

    private static final class DefaultTaskDependency implements TaskDependency {

        private final Set<Task> tasks;

        DefaultTaskDependency(Task task) {
            this.tasks = Collections.singleton(task);
        }

        @Override
        public Set<? extends Task> getDependencies(Task task) {
            return tasks;
        }
    }

    public AARPublishArtifact(
            String name,
            String classifier,
            OutputFileTask task) {
        this.name = name;
        this.classifier = classifier;
        this.task = task;
        this.taskDependency = new DefaultTaskDependency((Task) task);
    }


    @Override
    public String getName() {
        return name;
    }

    @Override
    public String getExtension() {
        return "aar";
    }

    @Override
    public String getType() {
        return "aar";
    }

    @Override
    public String getClassifier() {
        return classifier;
    }

    @Override
    public File getFile() {
        return task.getOutputFile();
    }

    @Override
    public Date getDate() {
        return null;
    }

    @Override
    public TaskDependency getBuildDependencies() {
        return taskDependency;
    }
}
