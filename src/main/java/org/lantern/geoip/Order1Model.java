package org.lantern.geoip;

import java.util.List;

import com.sachingarg.FenwickTreeModel;
import com.sachingarg.RCModel;

public class Order1Model implements RCModel {

    protected FenwickTreeModel frequency;
    protected FenwickTreeModel[] frequencyByCategory;

    protected final int noOfSymbols;

    protected int previous = -1;
    private final List<Integer> categoriesForItems;

    /**
     *
     * @param n  The number of symbols exclusive of EOF
     * @param categoriesForItems  The category for each of the n items
     * @param nCategories  The number of categories
     */
    public Order1Model(int n, List<Integer> categoriesForItems, int nCategories) {
        noOfSymbols = n + 1; // include eof
        frequency = new FenwickTreeModel(n);
        frequencyByCategory = new FenwickTreeModel[nCategories];
        this.categoriesForItems = categoriesForItems;
    }

    @Override
    public int getCumulativeFrequency(int i) {
        if (previous < 0)
            return frequency.getCumulativeFrequency(i);

        int category = categoriesForItems.get(previous);
        if (frequencyByCategory[category] == null) {
            return frequency.getCumulativeFrequency(i);
        }
        return frequencyByCategory[category].getCumulativeFrequency(i);
    }

    @Override
    public int getNumberOfSymbols() {
        return noOfSymbols;
    }

    @Override
    public void update(int i) {
        // update the raw frequency table
        frequency.update(i);
        // and the conditioned table
        if (previous != -1) {
            int category = categoriesForItems.get(previous);
            if (frequencyByCategory[category] == null) {
                frequencyByCategory[category] = new FenwickTreeModel(noOfSymbols);
            }
            frequencyByCategory[category].update(i);
        }
        previous = i;
    }

    public void setPrevious(int previous) {
        this.previous = previous;
    }

    @Override
    public int getSymbolForFrequency(int count) {
        if (previous < 0)
            return frequency.getSymbolForFrequency(count);

        int category = categoriesForItems.get(previous);
        if (frequencyByCategory[category] == null) {
            return frequency.getSymbolForFrequency(count);
        }
        return frequencyByCategory[category].getSymbolForFrequency(count);
    }
}
