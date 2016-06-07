package reporter

import (
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/getlantern/measured"
	"github.com/stretchr/testify/assert"
)

/*func TestDefaultTags(t *testing.T) {
	nr := startWithMockReporter()
	defer Stop()
	SetDefaults(map[string]string{"app": "test-app"})
	reportError("test-remoteAddr", fmt.Errorf("test-error"), "dial-phase")
	time.Sleep(100 * time.Millisecond)
	if assert.Equal(t, 1, len(nr.s)) {
		assert.Equal(t, "test-app", nr.s[0].Tags["app"], "should report with default tags")
	}
}*/

func TestWriteLineProtocol(t *testing.T) {
	chReq := make(chan []string, 1)
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := ioutil.ReadAll(r.Body)
		user, pass, ok := r.BasicAuth()
		assert.True(t, ok, "should send basic auth")
		chReq <- []string{user, pass, string(b)}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer ts.Close()
	ir := NewInfluxDBReporter(ts.URL, "test-user", "test-password", "testdb", nil)
	e := ir.ReportError(map[*measured.Error]int{&measured.Error{
		ID:    "fl-nl-xxx",
		Error: "test error",
		Phase: "dial",
	}: 1})
	assert.NoError(t, e, "should send to influxdb without error")
	req := <-chReq
	assert.Equal(t, 3, len(req))
	assert.Equal(t, req[0], "test-user", "")
	assert.Equal(t, req[1], "test-password", "")
	assert.Contains(t, req[2], "errors,", "should send measurement")
	assert.Contains(t, req[2], "error=test\\ error", "should send tag")
	assert.Contains(t, req[2], "id=fl-nl-xxx", "should send tag")
	assert.Contains(t, req[2], " count=1i ", "should send field")
	assert.NotContains(t, req[2], ", count=1i", "should not have trailing comma")
}

func TestCheckContent(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	ir := NewInfluxDBReporter(ts.URL, "test-user", "test-password", "testdb", nil).(*influxDBReporter)
	e := ir.submit([]*submitData{&submitData{"bytes", map[string]string{}, map[string]interface{}{}}})
	assert.Error(t, e, "should error if no tag or field specified")
	e = ir.submit([]*submitData{&submitData{"bytes", map[string]string{}, map[string]interface{}{"value": 3}}})
	assert.Error(t, e, "should error if no tag specified")
	e = ir.submit([]*submitData{&submitData{"bytes", map[string]string{"server": "fl-nl-xxx"}, map[string]interface{}{}}})
	assert.Error(t, e, "should error if no field specified")
	e = ir.submit([]*submitData{&submitData{"bytes",
		map[string]string{"server": "fl-nl-xxx"},
		map[string]interface{}{"value": 3}}})
	assert.NoError(t, e, "should have no error for valid stat")
	e = ir.submit([]*submitData{&submitData{"bytes",
		map[string]string{"server": "fl-nl-xxx"},
		map[string]interface{}{"value": ""}}})
	assert.Error(t, e, "should have error if field is empty")
	e = ir.submit([]*submitData{&submitData{"bytes",
		map[string]string{"server": ""},
		map[string]interface{}{"value": "3"}}})
	assert.Error(t, e, "should have error if tag is empty")
}

func TestRealProxyServer(t *testing.T) {
	ir := NewInfluxDBReporter("https://influx.getlantern.org/", "test", "test", "lantern", nil)
	e := ir.ReportError(map[*measured.Error]int{&measured.Error{
		ID:    "fl-nl-xxx",
		Error: "test error",
		Phase: "dial",
	}: 1})
	assert.NoError(t, e, "should send to influxdb without error")
}
