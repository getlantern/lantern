package org.lantern;

public class TestCategories {

    public interface SlowTests {}
    public interface IntegrationTests extends SlowTests {}
    public interface PerformanceTests extends SlowTests {}
    
    public interface TrustStoreTests {}
}
