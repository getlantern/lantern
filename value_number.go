package otto

import (
    "math"
    "strconv"
	"fmt"
	"strings"
	"regexp"
)

var stringToNumberParseInteger = regexp.MustCompile(`^(?:0[xX])`)

func stringToFloat(value string) float64 {
	value = strings.TrimSpace(value)

	if value == "" {
		return 0
	}

	parseFloat := false
	if strings.IndexRune(value, '.') != -1 {
		parseFloat = true
	} else if stringToNumberParseInteger.MatchString(value) {
		parseFloat = false
	} else {
		parseFloat = true
	}

	if (parseFloat) {
		number, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return math.NaN()
		}
		return number
	}

	number, err := strconv.ParseInt(value, 0, 64)
	if err != nil {
		return math.NaN()
	}
	return float64(number)
}

func toNumber(value Value) Value {
	if value._valueType == valueNumber {
		return value
	}
	return Value{valueNumber, toFloat(value)}
}

func toFloat(value Value) float64 {
	switch value._valueType {
	case valueUndefined:
		return math.NaN()
	case valueNull:
		return 0
	}
	switch value := value.value.(type) {
	case bool:
		if value {
			return 1
		}
		return 0
	case int:
		return float64(value)
	case int8:
		return float64(value)
	case int16:
		return float64(value)
	case int32:
		return float64(value)
	case int64:
		return float64(value)
	case uint:
		return float64(value)
	case uint8:
		return float64(value)
	case uint16:
		return float64(value)
	case uint32:
		return float64(value)
	case uint64:
		return float64(value)
	case float64:
        return value
	case string:
		return stringToFloat(value)
	case *_object:
		return toFloat(value.DefaultValue(defaultValueHintNumber))
	}
    panic(fmt.Errorf("toFloat(%T)", value.value))
}

const (
	float_2_32 float64 = 4294967296.0
	float_2_31 float64 = 2147483648.0
	float_2_16 float64 = 65536.0
	integer_2_32 int64 = 4294967296
	integer_2_31 int64 = 2146483648
	sqrt1_2 float64 = math.Sqrt2/2
)

func toIntegerFloat(value Value) float64 {
	floatValue := value.toFloat()
	if math.IsNaN(floatValue) {
		return 0
	}
	if floatValue > 0 {
		return math.Floor(floatValue)
	}
	return math.Ceil(floatValue)
}

func toInteger(value Value) int64 {
	{
		switch value := value.value.(type) {
		case int8:
			return int64(value)
		case int16:
			return int64(value)
		case int32:
			return int64(value)
		}
	}
	switch value._valueType {
	case valueUndefined, valueNull:
		return 0
	}
	floatValue := value.toFloat()
	if math.IsNaN(floatValue) {
		return 0
	} else if math.IsInf(floatValue, 0) {
		panic(hereBeDragons())
	}
	if floatValue > 0 {
		return int64(math.Floor(floatValue))
	}
	return int64(math.Ceil(floatValue))
}

// ECMA 262: 9.5
func toI32(value Value) int32 {
	{
		switch value := value.value.(type) {
		case int8:
			return int32(value)
		case int16:
			return int32(value)
		case int32:
			return value
		}
	}
	floatValue := value.toFloat()
	if math.IsNaN(floatValue) || math.IsInf(floatValue, 0) {
		return 0
	}
	if floatValue == 0 { // This will work for +0 & -0
		return 0
	}
	remainder := math.Mod(floatValue, float_2_32)
	if remainder > 0 {
		remainder = math.Floor(remainder)
	} else {
		remainder = math.Ceil(remainder) + float_2_32
	}
	if remainder > float_2_31 {
		return int32(remainder - float_2_32)
	}
	return int32(remainder)
}

func toUI32(value Value) uint32 {
	{
		switch value := value.value.(type) {
		case int8:
			return uint32(value)
		case int16:
			return uint32(value)
		case uint8:
			return uint32(value)
		case uint16:
			return uint32(value)
		case uint32:
			return value
		}
	}
	floatValue := value.toFloat()
	if math.IsNaN(floatValue) || math.IsInf(floatValue, 0) {
		return 0
	}
	if floatValue == 0 {
		return 0
	}
	remainder := math.Mod(floatValue, float_2_32)
	if remainder > 0 {
		remainder = math.Floor(remainder)
	} else {
		remainder = math.Ceil(remainder) + float_2_32
	}
	return uint32(remainder)
}

func toUI16(value Value) uint16 {
	{
		switch value := value.value.(type) {
		case int8:
			return uint16(value)
		case uint8:
			return uint16(value)
		case uint16:
			return value
		}
	}
	floatValue := value.toFloat()
	if math.IsNaN(floatValue) || math.IsInf(floatValue, 0) {
		return 0
	}
	if floatValue == 0 {
		return 0
	}
	remainder := math.Mod(floatValue, float_2_16)
	if remainder > 0 {
		remainder = math.Floor(remainder)
	} else {
		remainder = math.Ceil(remainder) + float_2_16
	}
	return uint16(remainder)
}
