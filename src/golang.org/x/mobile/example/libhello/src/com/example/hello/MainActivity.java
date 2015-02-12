/*
 * Copyright 2014 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package com.example.hello;

import go.Go;
import go.hi.Hi;
import android.app.Activity;
import android.os.Bundle;

/*
 * MainActivity is the entry point for the libhello app.
 *
 * From here, the Go runtime is initialized and a Go function is
 * invoked via gobind language bindings.
 *
 * See example/libhello/README for details.
 */
public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Go.init(getApplicationContext());
        Hi.Hello("world");
    }
}
