package org.lantern.state;

class PeerCount {
    public int give;
    public int get;

    private int giveGet;
    
    public int getGiveGet() {
        //return give + get;
        return giveGet;
    }

    /*
     * This setter intentionally does nothing; it's only here because otherwise
     * Jackson will complain
     */
    public void setGiveGet() {
    }
}