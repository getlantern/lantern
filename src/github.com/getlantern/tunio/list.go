package tunio

import (
	"errors"
	"sync"
)

type List interface {
	Head() int
	Tail() int
	Size() int
	Add(key int, value interface{}) error
	Remove(key int) error
	Get(key int) interface{}
}

type listNode struct {
	k int
	v interface{}
	p *listNode
	n *listNode
}

type list struct {
	maxLength int
	head      *listNode
	tail      *listNode
	nodes     map[int]*listNode
	m         sync.RWMutex
}

func (ls *list) Head() int {
	ls.m.RLock()
	defer ls.m.RUnlock()
	if ls.head == nil {
		return -1
	}
	return ls.head.k
}

func (ls *list) Tail() int {
	ls.m.RLock()
	defer ls.m.RUnlock()
	if ls.tail == nil {
		return -1
	}
	return ls.tail.k
}

func (ls *list) Size() int {
	ls.m.RLock()
	defer ls.m.RUnlock()
	return len(ls.nodes)
}

func (ls *list) Add(key int, value interface{}) error {
	node := ls.getNode(key)

	if node == nil {
		node = &listNode{k: key}
	} else {
		ls.Remove(key)
	}

	for ls.Size() >= ls.maxLength {
		ls.Remove(ls.tail.k)
	}

	ls.m.Lock()
	defer ls.m.Unlock()

	node.v = value

	ls.nodes[node.k] = node

	if ls.head == nil {
		// The list is empty.
		ls.head = node
		ls.tail = node
		return nil
	}

	if ls.head == node {
		// Node is already in place.
		return nil
	}

	// Check if our node is at the tail.
	if node == ls.tail {
		// Which node comes before tail?
		tail := ls.tail.p
		tail.n = nil
		// Updating tail.
		ls.tail = tail
	}

	// Current head
	head := ls.head

	// node <-> head
	node.n = head
	head.p = node

	node.p = nil // this is not at the head, nothing comes before.

	// Updating head.
	ls.head = node

	return nil
}

func (ls *list) Remove(key int) error {
	node := ls.getNode(key)

	if node == nil {
		return errors.New("No such key.")
	}

	ls.m.Lock()

	if node == ls.head {
		ls.head = node.n
	}

	if node == ls.tail {
		ls.tail = node.p
	}

	if node.p != nil {
		prev := node.p
		prev.n = node.n
	}

	if node.n != nil {
		next := node.n
		next.p = node.p
	}

	delete(ls.nodes, node.k)

	ls.m.Unlock()

	return nil
}

func (ls *list) Get(key int) interface{} {
	node := ls.getNode(key)
	if node == nil {
		return nil
	}
	return node.v
}

func (ls *list) getNode(key int) *listNode {
	ls.m.RLock()
	defer ls.m.RUnlock()
	for node := ls.head; node != nil; node = node.n {
		if node.k == key {
			return node
		}
	}
	return nil
}

func NewConnList(maxLength int) List {
	return &list{
		maxLength: maxLength,
		nodes:     make(map[int]*listNode),
	}
}
