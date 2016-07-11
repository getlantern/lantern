package stripe

import (
	"errors"
	"reflect"
	"testing"
)

func TestIterEmpty(t *testing.T) {
	tq := testQuery{{nil, ListMeta{}, nil}}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if len(g) != 0 {
		t.Fatalf("results = %v want empty", g)
	}
	if gerr != nil {
		t.Fatalf("err = %v want nil", gerr)
	}
}

func TestIterEmptyErr(t *testing.T) {
	tq := testQuery{{nil, ListMeta{}, errTest}}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if len(g) != 0 {
		t.Fatalf("results = %v want empty", g)
	}
	if gerr != errTest {
		t.Fatalf("err = %v want %v", gerr, errTest)
	}
}

func TestIterOne(t *testing.T) {
	tq := testQuery{{[]interface{}{1}, ListMeta{}, nil}}
	want := []interface{}{1}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != nil {
		t.Fatalf("err = %v want %v", gerr, nil)
	}
}

func TestIterOneErr(t *testing.T) {
	tq := testQuery{{[]interface{}{1}, ListMeta{}, errTest}}
	want := []interface{}{1}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != errTest {
		t.Fatalf("err = %v want %v", gerr, errTest)
	}
}

func TestIterPage2Empty(t *testing.T) {
	tq := testQuery{
		{[]interface{}{&item{"x"}}, ListMeta{0, true, ""}, nil},
		{nil, ListMeta{}, nil},
	}
	want := []interface{}{&item{"x"}}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != nil {
		t.Fatalf("err = %v want %v", gerr, nil)
	}
}

func TestIterPage2EmptyErr(t *testing.T) {
	tq := testQuery{
		{[]interface{}{&item{"x"}}, ListMeta{0, true, ""}, nil},
		{nil, ListMeta{}, errTest},
	}
	want := []interface{}{&item{"x"}}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != errTest {
		t.Fatalf("err = %v want %v", gerr, errTest)
	}
}

func TestIterTwoPages(t *testing.T) {
	tq := testQuery{
		{[]interface{}{&item{"x"}}, ListMeta{0, true, ""}, nil},
		{[]interface{}{2}, ListMeta{0, false, ""}, nil},
	}
	want := []interface{}{&item{"x"}, 2}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != nil {
		t.Fatalf("err = %v want nil", gerr)
	}
}

func TestIterTwoPagesErr(t *testing.T) {
	tq := testQuery{
		{[]interface{}{&item{"x"}}, ListMeta{0, true, ""}, nil},
		{[]interface{}{2}, ListMeta{0, false, ""}, errTest},
	}
	want := []interface{}{&item{"x"}, 2}
	g, gerr := collect(GetIter(nil, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != errTest {
		t.Fatalf("err = %v want %v", gerr, errTest)
	}
}

func TestIterReversed(t *testing.T) {
	tq := testQuery{{[]interface{}{1, 2}, ListMeta{}, nil}}
	want := []interface{}{2, 1}
	g, gerr := collect(GetIter(&ListParams{End: "x"}, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != nil {
		t.Fatalf("err = %v want %v", gerr, nil)
	}
}

func TestIterReversedTwoPages(t *testing.T) {
	tq := testQuery{
		{[]interface{}{&item{"3"}, 4}, ListMeta{0, true, ""}, nil},
		{[]interface{}{1, 2}, ListMeta{}, nil},
	}
	want := []interface{}{4, &item{"3"}, 2, 1}
	g, gerr := collect(GetIter(&ListParams{End: "x"}, nil, tq.query))
	if len(tq) != 0 {
		t.Fatalf("expect all pages to be fetched")
	}
	if !reflect.DeepEqual(g, want) {
		t.Fatalf("results = %v want %v", g, want)
	}
	if gerr != nil {
		t.Fatalf("err = %v want %v", gerr, nil)
	}
}

var errTest = errors.New("test error")

type item struct {
	ID string
}

type testQuery []struct {
	v []interface{}
	m ListMeta
	e error
}

func (tq *testQuery) query(*RequestValues) ([]interface{}, ListMeta, error) {
	x := (*tq)[0]
	*tq = (*tq)[1:]
	return x.v, x.m, x.e
}

func collect(it *Iter) ([]interface{}, error) {
	var g []interface{}
	for it.Next() {
		g = append(g, it.Current())
	}
	return g, it.Err()
}

func TestReverse(t *testing.T) {
	var cases = [][]interface{}{
		{},
		{1},
		{1, 2},
		{1, 2, 3},
		{1, 2, 3, 4},
	}
	for _, a := range cases {
		b := make([]interface{}, len(a))
		copy(b, a)
		reverse(b)
		for i, g := range b {
			if w := a[len(a)-1-i]; !reflect.DeepEqual(g, w) {
				t.Errorf("reverse(%v)[%d] = %v want %v", a, i, g, w)
			}
		}
	}
}
