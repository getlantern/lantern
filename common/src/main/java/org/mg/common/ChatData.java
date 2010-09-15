package org.mg.common;

import javax.management.MXBean;

@MXBean(true)
public interface ChatData {

    double getRate();
    
    int getAverageMessageSize();
    
    int getTotalMessages();
    
    long getTotalBytes();
}
