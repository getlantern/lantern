package org.lantern;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

import org.junit.Test;

public class SortTest {
    @Test
    public void testIt() {
        List<Integer> l = new ArrayList<Integer>();
        l.add(5);
        l.add(1);
        l.add(4);
        l.add(2);
        l.add(3);
        l.add(7);
        Collections.sort(l, new C());
        System.out.println(l);
    }

    private static class C implements Comparator<Integer> {
        @Override
        public int compare(Integer o1, Integer o2) {
            System.out.println("Comparing " + o1 + " to " + o2);
            return o1 - o2;
        }
    }
}
