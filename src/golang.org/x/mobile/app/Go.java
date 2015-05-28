package go;

import android.content.Context;
import android.os.Looper;
import android.util.Log;

// Go is an entry point for libraries compiled in Go.
// In an app's Application.onCreate, call:
//
// 	Go.init(getApplicationContext());
//
// When the function returns, it is safe to start calling
// Go code.
public final class Go {
	// init loads libgojni.so and starts the runtime.
	public static void init(final Context ctx) {
		if (Looper.myLooper() != Looper.getMainLooper()) {
			Log.wtf("Go", "Go.init must be called from main thread (looper="+Looper.myLooper().toString()+")");
		}
		if (running) {
			return;
		}
		running = true;

		// TODO(crawshaw): context.registerComponentCallbacks for runtime.GC

		System.loadLibrary("gojni");
		Go.run(ctx);
		new Thread("GoReceive") {
			public void run() { Seq.receive(); }
		}.start();
	}

	private static boolean running = false;

	private static native void run(Context ctx);
}
