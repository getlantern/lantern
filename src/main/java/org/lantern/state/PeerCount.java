package org.lantern.state;

class PeerCount {
    public int give;
    public int get;

    public int getGiveGet() {
        return give + get;
    }

    /*
     * This setter intentionally does nothing; it's only here because otherwise
     * Jackson will complain
     */
    public void setGiveGet() {
    }
}