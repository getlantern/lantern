package waddell

import (
	"fmt"
)

// Out returns the (one and only) channel for writing to the topic identified by
// the given id.
func (c *Client) Out(id TopicId) chan<- *MessageOut {
	if c.isClosed() {
		panic("Attempted to obtain out topic on closed client")
	}

	c.topicsOutMutex.Lock()
	defer c.topicsOutMutex.Unlock()
	t := c.topicsOut[id]
	if t == nil {
		t = &topic{
			id:     id,
			client: c,
			out:    make(chan *MessageOut),
		}
		c.topicsOut[id] = t
		go t.processOut()
	}
	return t.out
}

// In returns the (one and only) channel for receiving from the topic identified
// by the given id.
func (c *Client) In(id TopicId) <-chan *MessageIn {
	if c.isClosed() {
		panic("Attempted to obtain in topic on closed client")
	}

	return c.in(id, true)
}

type topic struct {
	id     TopicId
	client *Client
	out    chan *MessageOut
}

func (t *topic) processOut() {
	for msg := range t.out {
		if t.client.isClosed() {
			return
		}
		info := t.client.getConnInfo()
		if info.err != nil {
			log.Errorf("Unable to get connection to waddell, stop sending to %d: %s", t.id, info.err)
			t.client.Close()
			return
		}
		pieces := make([][]byte, 0, 2+len(msg.Body))
		pieces = append(pieces, msg.To.toBytes(), t.id.toBytes())
		pieces = append(pieces, msg.Body...)
		_, err := info.writer.WritePieces(pieces...)
		if err != nil {
			t.client.connError(err)
			continue
		}
	}
}

func (c *Client) in(id TopicId, create bool) chan *MessageIn {
	c.topicsInMutex.Lock()
	defer c.topicsInMutex.Unlock()
	ch := c.topicsIn[id]
	if ch == nil && create {
		ch = make(chan *MessageIn)
		c.topicsIn[id] = ch
	}
	return ch
}

func (c *Client) processInbound() {
	for {
		if c.isClosed() {
			return
		}
		info := c.getConnInfo()
		if info.err != nil {
			log.Errorf("Unable to get connection to waddell, stop receiving: %s", info.err)
			c.Close()
			return
		}
		msg, err := info.receive()
		if err != nil {
			c.connError(err)
			continue
		}
		topicIn := c.in(msg.topic, false)
		if topicIn != nil {
			topicIn <- msg
		}
	}
}

func (info *connInfo) receive() (*MessageIn, error) {
	log.Trace("Receiving")
	frame, err := info.reader.ReadFrame()
	log.Tracef("Received %d: %s", len(frame), err)
	if err != nil {
		return nil, err
	}
	if len(frame) < WaddellHeaderLength {
		return nil, fmt.Errorf("Frame not long enough to contain waddell headers. Needed %d bytes, found only %d.", WaddellHeaderLength, len(frame))
	}
	peer, err := readPeerId(frame)
	if err != nil {
		return nil, err
	}
	topic, err := readTopicId(frame[PeerIdLength:])
	return &MessageIn{
		From:  peer,
		topic: topic,
		Body:  frame[PeerIdLength+TopicIdLength:],
	}, nil
}
