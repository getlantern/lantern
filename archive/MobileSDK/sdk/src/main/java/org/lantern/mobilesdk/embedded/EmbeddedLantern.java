package org.lantern.mobilesdk.embedded;

import android.content.Context;

import org.lantern.mobilesdk.Lantern;
import org.lantern.mobilesdk.LanternNotRunningException;
import org.lantern.mobilesdk.StartResult;

public class EmbeddedLantern extends Lantern {
    static {
        // Track extra info about Android for logging to Loggly.
        EmbeddedLantern.addLoggingMetadata("androidDevice", android.os.Build.DEVICE);
        org.lantern.mobilesdk.Lantern.addLoggingMetadata("androidModel", android.os.Build.MODEL);
        org.lantern.mobilesdk.Lantern.addLoggingMetadata("androidSdkVersion", "" + android.os.Build.VERSION.SDK_INT + " (" + android.os.Build.VERSION.RELEASE + ")");
    }

    @Override
    protected StartResult start(Context context, int timeoutMillis) throws LanternNotRunningException {
        return start(configDirFor(context, ""), timeoutMillis);
    }

    public StartResult start(String configDir, int timeoutMillis) throws LanternNotRunningException {
        try {
            go.lantern.Lantern.StartResult result = go.lantern.Lantern.Start(configDir, timeoutMillis);
            return new StartResult(result.getHTTPAddr(), result.getSOCKS5Addr());
        } catch (Exception e) {
            throw new LanternNotRunningException("Unable to start EmbeddedLantern: " + e.getMessage(), e);
        }
    }
}
