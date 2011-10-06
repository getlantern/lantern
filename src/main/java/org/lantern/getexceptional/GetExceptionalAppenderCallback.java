package org.lantern.getexceptional;

import java.util.Collection;

import org.apache.commons.httpclient.NameValuePair;

/**
 * Interface for making callbacks prior to sending data to GetExceptional.
 */
public interface GetExceptionalAppenderCallback {

    /**
     * Allows the creator of a GetExceptional log4j appender to add arbitrary
     * data or edit existing data prior to the exception being reported.
     * 
     * @param dataList The data for submission.
     */
    void addData(Collection<NameValuePair> dataList);
}
