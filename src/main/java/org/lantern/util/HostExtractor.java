package org.lantern.util;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * HostExtractor extracts host names from urls
 */
public class HostExtractor {
    private static final Pattern URL_PATTERN = Pattern.compile(
            "(https?://)?([^:/]+).*", Pattern.CASE_INSENSITIVE);

    public static String extractHost(String url) {
        Matcher matcher = URL_PATTERN.matcher(url);
        if (!matcher.matches()) {
            return null;
        }
        return matcher.group(2);
    }
}
