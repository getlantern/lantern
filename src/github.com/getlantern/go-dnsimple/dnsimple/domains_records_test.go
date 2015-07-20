package dnsimple

import (
	"fmt"
	"net/http"
	"reflect"
	"strings"
	"testing"
)

func TestRecords_recordPath(t *testing.T) {
	var pathTest = []struct {
		domainInput interface{}
		recordInput interface{}
		expected    string
	}{
		{"example.com", nil, "domains/example.com/records"},
		{"example.com", 2, "domains/example.com/records/2"},
		{1, nil, "domains/1/records"},
		{1, 2, "domains/1/records/2"},
	}

	for _, pt := range pathTest {
		actual := recordPath(pt.domainInput, pt.recordInput)
		if actual != pt.expected {
			t.Errorf("recordPath(%+v, %+v): expected %s, actual %s", pt.domainInput, pt.recordInput, pt.expected, actual)
		}
	}
}

func TestDomainsService_ListRecords_all(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		fmt.Fprint(w, `[{"record":{"id":1, "name":"foo.example.com"}}]`)
	})

	records, _, err := client.Domains.ListRecords("example.com", "", "")

	if err != nil {
		t.Errorf("Domains.ListRecords returned error: %v", err)
	}

	want := []Record{{Id: 1, Name: "foo.example.com"}}
	if !reflect.DeepEqual(records, want) {
		t.Fatalf("Domains.ListRecords returned %+v, want %+v", records, want)
	}
}

func TestDomainsService_ListRecords_subdomain(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		testFormValues(t, r, values{"name": "foo"})

		fmt.Fprint(w, `[{"record":{"id":1, "name":"foo.example.com"}}]`)
	})

	records, _, err := client.Domains.ListRecords("example.com", "foo", "")

	if err != nil {
		t.Errorf("Domains.ListRecords returned error: %v", err)
	}

	want := []Record{{Id: 1, Name: "foo.example.com"}}
	if !reflect.DeepEqual(records, want) {
		t.Fatalf("Domains.ListRecords returned %+v, want %+v", records, want)
	}
}

func TestDomainsService_ListRecords_type(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		testFormValues(t, r, values{"name": "foo", "type": "CNAME"})

		fmt.Fprint(w, `[{"record":{"id":1, "name":"foo.example.com"}}]`)
	})

	records, _, err := client.Domains.ListRecords("example.com", "foo", "CNAME")

	if err != nil {
		t.Errorf("Domains.ListRecords returned error: %v", err)
	}

	want := []Record{{Id: 1, Name: "foo.example.com"}}
	if !reflect.DeepEqual(records, want) {
		t.Fatalf("Domains.ListRecords returned %+v, want %+v", records, want)
	}
}

func TestDomainsService_CreateRecord(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records", func(w http.ResponseWriter, r *http.Request) {
		want := make(map[string]interface{})
		want["record"] = map[string]interface{}{"name": "foo", "content": "192.168.0.10", "record_type": "A"}

		testMethod(t, r, "POST")
		testRequestJSON(t, r, want)

		w.WriteHeader(http.StatusCreated)
		fmt.Fprintf(w, `{"record":{"id":2, "domain_id":1, "name":"foo"}}`)
	})

	recordValues := Record{Name: "foo", Content: "192.168.0.10", Type: "A"}
	record, _, err := client.Domains.CreateRecord("example.com", recordValues)

	if err != nil {
		t.Errorf("Domains.CreateRecord returned error: %v", err)
	}

	want := Record{Id: 2, DomainId: 1, Name: "foo"}
	if !reflect.DeepEqual(record, want) {
		t.Fatalf("Domains.CreateRecord returned %+v, want %+v", record, want)
	}
}

func TestDomainsService_GetRecord(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records/1539", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		fmt.Fprintf(w, `{"record":{"id":2, "domain_id":1, "name":"foo"}}`)
	})

	record, _, err := client.Domains.GetRecord("example.com", 1539)

	if err != nil {
		t.Errorf("Domains.GetRecord returned error: %v", err)
	}

	want := Record{Id: 2, DomainId: 1, Name: "foo"}
	if !reflect.DeepEqual(record, want) {
		t.Fatalf("Domains.GetRecord returned %+v, want %+v", record, want)
	}
}

func TestDomainsService_UpdateRecord(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records/2", func(w http.ResponseWriter, r *http.Request) {
		want := make(map[string]interface{})
		want["record"] = map[string]interface{}{"content": "192.168.0.10", "name": "bar"}

		testMethod(t, r, "PUT")
		testRequestJSON(t, r, want)

		fmt.Fprint(w, `{"record":{"id":2, "domain_id":1, "name":"bar", "content": "192.168.0.10"}}`)
	})

	recordValues := Record{Name: "bar", Content: "192.168.0.10", Type: "A"}
	record, _, err := client.Domains.UpdateRecord("example.com", 2, recordValues)

	if err != nil {
		t.Errorf("Domains.UpdateRecord returned error: %v", err)
	}

	want := Record{Id: 2, DomainId: 1, Name: "bar", Content: "192.168.0.10"}
	if !reflect.DeepEqual(record, want) {
		t.Fatalf("Domains.UpdateRecord returned %+v, want %+v", record, want)
	}
}

func TestDomainsService_DeleteRecord(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records/2", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "DELETE")
		// fmt.Fprint(w, `{}`)
	})

	_, err := client.Domains.DeleteRecord("example.com", 2)

	if err != nil {
		t.Errorf("Domains.DeleteRecord returned error: %v", err)
	}
}

func TestDomainsService_DeleteRecord_failed(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/records/2", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "DELETE")

		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, `{"message":"Invalid request"}`)
	})

	_, err := client.Domains.DeleteRecord("example.com", 2)
	if err == nil {
		t.Errorf("Domains.DeleteRecord expected error to be returned")
	}

	if match := "400 Invalid request"; !strings.Contains(err.Error(), match) {
		t.Errorf("Records.Delete returned %+v, should match %+v", err, match)
	}
}

func TestRecord_UpdateIP(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/24/records/42", func(w http.ResponseWriter, r *http.Request) {
		want := make(map[string]interface{})
		want["record"] = map[string]interface{}{"name": "foo", "content": "192.168.0.1"}

		testMethod(t, r, "PUT")
		testRequestJSON(t, r, want)

		fmt.Fprint(w, `{"record":{"id":24, "domain_id":42}}`)
	})

	record := Record{Id: 42, DomainId: 24, Name: "foo"}
	err := record.UpdateIP(client, "192.168.0.1")

	if err != nil {
		t.Errorf("UpdateIP returned error: %v", err)
	}
}
