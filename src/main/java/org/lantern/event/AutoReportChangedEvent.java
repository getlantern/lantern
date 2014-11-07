package org.lantern.event;

import org.lantern.state.Mode;

public class AutoReportChangedEvent {

    private boolean autoReport;

    public AutoReportChangedEvent(boolean autoReport) {
        super();
        this.autoReport = autoReport;
    }

    public boolean isAutoReport() {
        return autoReport;
    }

    @Override
    public String toString() {
        return "AutoReportChangedEvent [autoReport=" + autoReport + "]";
    }

}
