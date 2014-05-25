package org.lantern;

import java.io.IOException;
import java.net.InetAddress;

public class AllCensored implements Censored {

    @Override
    public boolean isExportRestricted(String string) throws IOException {
        return true;
    }

    @Override
    public boolean isCountryCodeCensored(String cc) {
        return true;
    }

    @Override
    public boolean isCensored(Country country) {
        return true;
    }

    @Override
    public boolean isCensored() {
        return true;
    }

    @Override
    public boolean isCensored(InetAddress address) {
        return true;
    }

}
