package org.lantern.state;

import org.codehaus.jackson.map.annotate.JsonDeserialize;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.lantern.annotation.Keep;

@Keep
@JsonSerialize(using = PeerCountSerializer.class)
@JsonDeserialize(using = PeerCountDeserializer.class)
public class PeerCount {
    private long give;
    private long get;

    public long getGive() {
        return give;
    }

    public void setGive(long give) {
        this.give = give;
    }

    public long getGet() {
        return get;
    }

    public void setGet(long get) {
        this.get = get;
    }
}