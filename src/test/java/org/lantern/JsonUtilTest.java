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

        public String getPropertyB() {
            return propertyB;
        }

        public void setPropertyB(String propertyB) {
            this.propertyB = propertyB;
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
        Child child = new Child();
        child.setPropertyA("Child A");
        child.setPropertyB("Child B");
        Container container = new Container();
        child.setPropertyA("Container A");
        child.setPropertyB("Container B");
        container.setChild(child);

        String json = JsonUtils.jsonify(container, Include.class);
        Container roundTripped = JsonUtils.decode(json, Container.class);

        assertEquals(container.propertyA, roundTripped.propertyA);
        assertEquals(container.child.propertyA, roundTripped.child.propertyA);

        assertNull(container.propertyB);
        assertNull(container.child.propertyB);
    }
}
