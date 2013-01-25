package otto

import (
	"fmt"
	"math"
)

func toString(value Value) string {
	if value._valueType == valueString {
		return value.value.(string)
	}
	if value.IsUndefined() {
		return "undefined"
	}
	if value.IsNull() {
		return "null"
	}
	switch realValue := value.value.(type) {
	case bool:
		return fmt.Sprintf("%v", realValue)
	case int, int8, int16, int32, int64:
		return fmt.Sprintf("%v", realValue)
	case uint, uint8, uint16, uint32, uint64:
		return fmt.Sprintf("%v", realValue)
	case float32:
		return fmt.Sprintf("%v", realValue)
	case float64:
		if math.IsNaN(realValue) {
			return "NaN"
		} else if math.IsInf(realValue, 0) {
			if math.Signbit(realValue) {
				return "-Infinity"
			}
			return "Infinity"
		}
		return fmt.Sprintf("%v", realValue)
	case string:
		return realValue
	case *_object:
		return toString(realValue.DefaultValue(defaultValueHintString))
	}
	panic(fmt.Errorf("toString(%v %T)", value.value, value.value))
}
