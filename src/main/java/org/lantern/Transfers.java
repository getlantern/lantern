package org.lantern;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Settings.PersistentSetting;
import org.lantern.Settings.RuntimeSetting;

/**
 * Class representing all uploads and downloads data.
 */
public class Transfers {

    
    // sum of past runs
    private long historicalUpBytes = 0;
    private long historicalDownBytes = 0;

    /*
    @JsonView(RuntimeSetting.class)
    public long getPeerCount() {
        return LanternHub.statsTracker().getPeerCount();
    }

    @JsonView(RuntimeSetting.class)
    public long getPeerCountThisRun() {
        return LanternHub.statsTracker().getPeerCountThisRun();
    }
    */
    
    // TODO: Add ncurrent and nlifetime

    @JsonView(RuntimeSetting.class)
    public long getBpsUp() {
        return LanternHub.statsTracker().getUpBytesPerSecond();
    }
    
    @JsonView(RuntimeSetting.class)
    public long getBpsDn() {
        return LanternHub.statsTracker().getDownBytesPerSecond();
    }
    
    @JsonView(RuntimeSetting.class)
    public long getBpsTotal() {
        return getBpsDn() + getBpsUp();
    }
    
    @JsonView(RuntimeSetting.class)
    public long getUpTotalThisRun() {
        return LanternHub.statsTracker().getUpBytesThisRun();
    }
    
    @JsonView(RuntimeSetting.class)
    public long getDownTotalThisRun() {
        return LanternHub.statsTracker().getDownBytesThisRun();
    }
    
    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public long getBytesUpLifetime() {
        return getUpTotalThisRun() + historicalUpBytes;
    }

    public void setUpTotalLifetime(final long value) {
        historicalUpBytes = value;
    }

    @JsonView({RuntimeSetting.class, PersistentSetting.class})
    public long getBytesDnLifetime() {
        return getDownTotalThisRun() + historicalDownBytes;
    }

    public void setDownTotalLifetime(final long value) {
        historicalDownBytes = value;
    }
    
    @JsonView({RuntimeSetting.class})
    public long getBytesTotalLifetime() {
        return getBytesDnLifetime() + getBytesUpLifetime();
    }
}
