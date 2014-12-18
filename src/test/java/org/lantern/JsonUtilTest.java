package org.lantern;

import static org.junit.Assert.*;

import org.codehaus.jackson.map.annotate.JsonView;
import org.junit.Test;

public class JsonUtilTest {
    public static class Include {
    };

    public static class Container {
        private Child child;

        private String propertyA;
        private String propertyB;
        private String propertyC;

        @JsonView({ Include.class })
        public Child getChild() {
            return child;
        }

        public void setChild(Child child) {
            this.child = child;
        }

        @JsonView({ Include.class })
        public String getPropertyA() {
            return propertyA;
        }

        public void setPropertyA(String propertyA) {
            this.propertyA = propertyA;
        }

        @JsonView()
        public String getPropertyB() {
            return propertyB;
        }

        public void setPropertyB(String propertyB) {
            this.propertyB = propertyB;
        }

        public String getPropertyC() {
            return propertyC;
        }

        public void setPropertyC(String propertyC) {
            this.propertyC = propertyC;
        }

    }

    public static class Child {
        private String propertyA;
        private String propertyB;

        @JsonView({ Include.class })
        public String getPropertyA() {
            return propertyA;
        }

        public void setPropertyA(String propertyA) {
            this.propertyA = propertyA;
        }

        public String getPropertyB() {
            return propertyB;
        }

        public void setPropertyB(String propertyB) {
            this.propertyB = propertyB;
        }
    }

    @Test
    public void testJsonView() {
        Container orig = new Container();
        orig.setPropertyA("Val A");
        orig.setPropertyB("Val B");
        orig.setPropertyC("Val C");

        String json = JsonUtils.jsonify(orig, Include.class);
        Container roundTripped = JsonUtils.decode(json, Container.class);

        assertEquals(orig.propertyA, roundTripped.propertyA);
        
        // propertyB is omitted because it's not in the required JsonView
        assertNull(roundTripped.propertyB);
        
        // propertyC is not subjected to the JsonView mechanism because it
        // doesn't have a JsonView annotation
        assertEquals(orig.propertyC, roundTripped.propertyC);
    }
}
