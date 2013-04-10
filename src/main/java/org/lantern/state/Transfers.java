package org.lantern.state;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.Stats;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

/**
 * Class representing all uploads and downloads data.
 */
public class Transfers {

    private Stats statsTracker;

    public Transfers() {
        //for JSON loading
    }

    public Transfers(Stats tracker) {
        this.setStatsTracker(tracker);
    }

    // sum of past runs
    private long historicalUpBytes = 0;
    private long historicalDownBytes = 0;

    @JsonView({ Persistent.class })
    public void setHistoricalUpBytes(final long value) {
        historicalUpBytes = value;
    }

    @JsonView({ Persistent.class })
    public void setHistoricaDownBytes(final long value) {
        historicalDownBytes = value;
    }

    @JsonView({ Persistent.class })
    public long getHistoricalUpBytes() {
        return historicalUpBytes + getStatsTracker().getUpBytesThisRun();
    }

    @JsonView({ Persistent.class })
    public long getHistoricaDownBytes() {
        return historicalDownBytes + getStatsTracker().getDownBytesThisRun();
    }

    @JsonView({ Run.class })
    public long getBpsUp() {
        return getStatsTracker().getUpBytesPerSecond();
    }

    @JsonView({ Run.class })
    public long getBpsDn() {
        return getStatsTracker().getDownBytesPerSecond();
    }

    @JsonView({ Run.class })
    public long getBpsUpDn() {
        return getBpsUp() + getBpsDn();
    }

    @JsonView({ Run.class })
    public long getBpsTotal() {
        return getBpsDn() + getBpsUp();
    }

    @JsonView({ Run.class })
    public long getUpTotalThisRun() {
        return getStatsTracker().getUpBytesThisRun();
    }

    @JsonView({ Run.class })
    public long getDownTotalThisRun() {
        return getStatsTracker().getDownBytesThisRun();
    }

    @JsonView({ Run.class })
    public long getBytesUp() {
        return getUpTotalThisRun() + historicalUpBytes;
    }

    @JsonView({ Run.class })
    public long getBytesDn() {
        return getDownTotalThisRun() + historicalDownBytes;
    }

    @JsonView({ Run.class })
    public long getBytesUpDn() {
        return getBytesDn() + getBytesUp();
    }

    @JsonIgnore
    public Stats getStatsTracker() {
        return statsTracker;
    }

    @JsonIgnore
    public void setStatsTracker(Stats statsTracker) {
        this.statsTracker = statsTracker;
    }
}
