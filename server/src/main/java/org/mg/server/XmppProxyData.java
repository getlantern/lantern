package org.mg.server;

import javax.management.MXBean;

@MXBean(true)
public interface XmppProxyData {

    double getRate();
}
