package org.lantern.getexceptional;

import org.json.simple.JSONObject;

/**
 * Interface for making callbacks prior to sending data to GetExceptional.
 */
public interface GetExceptionalAppenderCallback {

    /**
     * Allows the creator of a GetExceptional log4j appender to add arbitrary
     * data or edit existing data prior to the exception being reported.
     * 
     * @param json The data for submission.
     */
    void addData(JSONObject json);
}
