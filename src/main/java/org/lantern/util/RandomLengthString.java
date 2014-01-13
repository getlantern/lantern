package org.lantern.util;

import java.security.SecureRandom;

/**
 * Generates a random length string.
 */
public class RandomLengthString {
    private final int maxLength;
    private final String[] preGeneratedStrings;
    private final ThreadLocal<SecureRandom> random = new ThreadLocal<SecureRandom>() {
        @Override
        protected SecureRandom initialValue() {
            return new SecureRandom();
        }
    };

    public RandomLengthString(int maxLength) {
        this.maxLength = maxLength;
        preGeneratedStrings = new String[maxLength];
        // Initialize all possible random length headers
        for (int i = 0; i < maxLength; i++) {
            char[] chars = new char[i];
            for (int j = 0; j < i; j++) {
                chars[j] = 'r';
            }
            preGeneratedStrings[i] = new String(chars);
        }
    }

    /**
     * Get the next random length header
     */
    public String next() {
        int index = random.get().nextInt(maxLength);
        return preGeneratedStrings[index];
    }
}
