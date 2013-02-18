package org.lantern.state;

import org.codehaus.jackson.map.annotate.JsonDeserialize;
import org.codehaus.jackson.map.annotate.JsonSerialize;

@JsonSerialize(using=PeerCountSerializer.class)
@JsonDeserialize(using=PeerCountDeserializer.class)
public class PeerCount {
    public long give;
    public long get;
}