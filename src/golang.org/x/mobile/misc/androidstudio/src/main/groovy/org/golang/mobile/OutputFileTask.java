/**
 * Copyright 2015 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package org.golang.mobile;

import java.io.File;

/**
 * A task that outputs a file.
 */
public interface OutputFileTask {
    File getOutputFile();
}
