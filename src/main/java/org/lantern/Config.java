package org.lantern;


public interface Config {

    String roster();
    
    String whitelist();

    String httpsEverywhere();

    String whitelist(String body);

    String roster(String body);

}
