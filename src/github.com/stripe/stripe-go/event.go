package stripe

import (
	"encoding/json"
	"fmt"
)

// Event is the resource representing a Stripe event.
// For more details see https://stripe.com/docs/api#events.
type Event struct {
	ID       string     `json:"id"`
	Live     bool       `json:"livemode"`
	Created  int64      `json:"created"`
	Data     *EventData `json:"data"`
	Webhooks uint64     `json:"pending_webhooks"`
	Type     string     `json:"type"`
	Req      string     `json:"request"`
	UserID   string     `json:"user_id"`
}

// EventData is the unmarshalled object as a map.
type EventData struct {
	Raw  json.RawMessage        `json:"object"`
	Prev map[string]interface{} `json:"previous_attributes"`
	Obj  map[string]interface{}
}

// EventList is a list of events as retrieved from a list endpoint.
type EventList struct {
	ListMeta
	Values []*Event `json:"data"`
}

// EventListParams is the set of parameters that can be used when listing events.
// For more details see https://stripe.com/docs/api#list_events.
type EventListParams struct {
	ListParams
	Created int64
	// Type is one of the values documented at https://stripe.com/docs/api#event_types.
	Type string
}

// GetObjValue returns the value from the e.Data.Obj bag based on the keys hierarchy.
func (e *Event) GetObjValue(keys ...string) string {
	return getValue(e.Data.Obj, keys)
}

// GetPrevValue returns the value from the e.Data.Prev bag based on the keys hierarchy.
func (e *Event) GetPrevValue(keys ...string) string {
	return getValue(e.Data.Prev, keys)
}

// UnmarshalJSON handles deserialization of the EventData.
// This custom unmarshaling exists so that we can keep both the map and raw data.
func (e *EventData) UnmarshalJSON(data []byte) error {
	type eventdata EventData
	var ee eventdata
	err := json.Unmarshal(data, &ee)
	if err != nil {
		return err
	}

	*e = EventData(ee)
	return json.Unmarshal(e.Raw, &e.Obj)
}

// getValue returns the value from the m map based on the keys.
func getValue(m map[string]interface{}, keys []string) string {
	node := m[keys[0]]

	for i := 1; i < len(keys); i++ {
		node = node.(map[string]interface{})[keys[i]]
	}

	if node == nil {
		return ""
	}

	return fmt.Sprintf("%v", node)
}
