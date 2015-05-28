package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"reflect"
	"strconv"
)

//-------------------------------------------------------------------------
// config
//
// Structure represents persistent config storage of the gocode daemon. Usually
// the config is located somewhere in ~/.config/gocode directory.
//-------------------------------------------------------------------------

type config struct {
	ProposeBuiltins  bool   `json:"propose-builtins"`
	LibPath          string `json:"lib-path"`
	Autobuild        bool   `json:"autobuild"`
	ForceDebugOutput string `json:"force-debug-output"`
}

var g_config = config{
	ProposeBuiltins:  false,
	LibPath:          "",
	Autobuild:        false,
	ForceDebugOutput: "",
}

var g_string_to_bool = map[string]bool{
	"t":     true,
	"true":  true,
	"y":     true,
	"yes":   true,
	"on":    true,
	"1":     true,
	"f":     false,
	"false": false,
	"n":     false,
	"no":    false,
	"off":   false,
	"0":     false,
}

func set_value(v reflect.Value, value string) {
	switch t := v; t.Kind() {
	case reflect.Bool:
		v, ok := g_string_to_bool[value]
		if ok {
			t.SetBool(v)
		}
	case reflect.String:
		t.SetString(value)
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		v, err := strconv.ParseInt(value, 10, 64)
		if err == nil {
			t.SetInt(v)
		}
	case reflect.Float32, reflect.Float64:
		v, err := strconv.ParseFloat(value, 64)
		if err == nil {
			t.SetFloat(v)
		}
	}
}

func list_value(v reflect.Value, name string, w io.Writer) {
	switch t := v; t.Kind() {
	case reflect.Bool:
		fmt.Fprintf(w, "%s %v\n", name, t.Bool())
	case reflect.String:
		fmt.Fprintf(w, "%s \"%v\"\n", name, t.String())
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		fmt.Fprintf(w, "%s %v\n", name, t.Int())
	case reflect.Float32, reflect.Float64:
		fmt.Fprintf(w, "%s %v\n", name, t.Float())
	}
}

func (this *config) list() string {
	str, typ := this.value_and_type()
	buf := bytes.NewBuffer(make([]byte, 0, 256))
	for i := 0; i < str.NumField(); i++ {
		v := str.Field(i)
		name := typ.Field(i).Tag.Get("json")
		list_value(v, name, buf)
	}
	return buf.String()
}

func (this *config) list_option(name string) string {
	str, typ := this.value_and_type()
	buf := bytes.NewBuffer(make([]byte, 0, 256))
	for i := 0; i < str.NumField(); i++ {
		v := str.Field(i)
		nm := typ.Field(i).Tag.Get("json")
		if nm == name {
			list_value(v, name, buf)
		}
	}
	return buf.String()
}

func (this *config) set_option(name, value string) string {
	str, typ := this.value_and_type()
	buf := bytes.NewBuffer(make([]byte, 0, 256))
	for i := 0; i < str.NumField(); i++ {
		v := str.Field(i)
		nm := typ.Field(i).Tag.Get("json")
		if nm == name {
			set_value(v, value)
			list_value(v, name, buf)
		}
	}
	this.write()
	return buf.String()

}

func (this *config) value_and_type() (reflect.Value, reflect.Type) {
	v := reflect.ValueOf(this).Elem()
	return v, v.Type()
}

func (this *config) write() error {
	data, err := json.Marshal(this)
	if err != nil {
		return err
	}

	// make sure config dir exists
	dir := config_dir()
	if !file_exists(dir) {
		os.MkdirAll(dir, 0755)
	}

	f, err := os.Create(config_file())
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = f.Write(data)
	if err != nil {
		return err
	}

	return nil
}

func (this *config) read() error {
	data, err := ioutil.ReadFile(config_file())
	if err != nil {
		return err
	}

	err = json.Unmarshal(data, this)
	if err != nil {
		return err
	}

	return nil
}
