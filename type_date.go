package otto

import (
	tme "time"
	"math"
	"fmt"
)

type _dateObject struct {
	time tme.Time // Time from the "time" package, a cached version of time
	epoch float64
	value Value
	isNaN bool
}

type _ecmaTime struct {
	year int
	month int
	day int
	hour int
	minute int
	second int
	millisecond int
	location *tme.Location // Basically, either local or UTC
}

func ecmaTime(goTime tme.Time) _ecmaTime {
	return _ecmaTime{
		goTime.Year(),
		dateFromGoMonth(goTime.Month()),
		goTime.Day(),
		goTime.Hour(),
		goTime.Minute(),
		goTime.Second(),
		goTime.Nanosecond() / (100 * 100 * 100),
		goTime.Location(),
	}
}

func (self *_ecmaTime) goTime() tme.Time {
	return tme.Date(
		self.year,
		dateToGoMonth(self.month),
		self.day,
		self.hour,
		self.minute,
		self.second,
		self.millisecond * (100 * 100 * 100),
		self.location,
	)
}

func (self *_dateObject) Time() tme.Time {
	return self.time
}

func (self *_dateObject) Epoch() float64 {
	return self.epoch
}

func (self *_dateObject) Value() Value {
	return self.value
}

func (self *_dateObject) SetNaN() {
	self.time = tme.Time{}
	self.epoch = math.NaN()
	self.value = NaNValue()
	self.isNaN = true
}

func (self *_dateObject) SetTime(time tme.Time) {
	self.Set(timeToEpoch(time))
}

func (self *_dateObject) Set(epoch float64) {
	// epoch
	self.epoch = epoch

	// time
	time, err := epochToTime(epoch)
	self.time = time // Is either a valid time, or the zero-value for time.Time

	// value & isNaN
	if err != nil {
		self.isNaN = true
		self.value = NaNValue()
	} else {
		self.value = toValue(epoch)
	}
}

func epochToTime(value float64) (time tme.Time, err error) {
	epochWithMilli := value
	if math.IsNaN(epochWithMilli) || math.IsInf(epochWithMilli, 0) {
		err = fmt.Errorf("Invalid time %v", value)
		return
	}

	epoch := int64(epochWithMilli / 1000)
	milli := int64(epochWithMilli) % 1000

	time = tme.Unix(int64(epoch), milli * 1000000).UTC()
	return
}

func timeToEpoch(time tme.Time) float64 {
	return float64(time.Unix() * 1000 + int64(time.Nanosecond() / 1000000))
}

func (runtime *_runtime) newDateObject(epoch float64) *_object {
	self := runtime.newObject()
	self.Class = "Date"

	// TODO Fix this, redundant arguments, etc.
	self.Date = &_dateObject{}
	self.Date.Set(epoch)
	return self
}

func dateObjectOf(_dateObject *_object) *_dateObject {
	if _dateObject == nil || _dateObject.Class != "Date" {
		panic(newTypeError())
	}
	return _dateObject.Date
}

// JavaScript is 0-based, Go is 1-based (15.9.1.4)
func dateToGoMonth(month int) tme.Month {
	return tme.Month(month + 1)
}

func dateFromGoMonth(month tme.Month) int {
	return int(month) - 1
}

// Both JavaScript & Go are 0-based (Sunday == 0)
func dateToGoDay(day int) tme.Weekday {
	return tme.Weekday(day)
}

func dateFromGoDay(day tme.Weekday) int {
	return int(day)
}

func newDateTime(argumentList []Value) (epoch float64) {

	pick := func(index int, default_ float64) (float64, bool) {
		if index >= len(argumentList) {
			return default_, false
		}
		value := toFloat(argumentList[index])
		if math.IsNaN(value) || math.IsInf(value, 0) {
			return 0, true
		}
		return value, false
	}

	if len(argumentList) >= 2 { // 2-argument, 3-argument, ...
		var year, month, day, hours, minutes, seconds, ms float64
		var invalid bool
		if year, invalid = pick(0, 1900.0); invalid {
			goto INVALID
		}
		if month, invalid = pick(1, 0.0); invalid {
			goto INVALID
		}
		if day, invalid = pick(2, 1.0); invalid {
			goto INVALID
		}
		if hours, invalid = pick(3, 0.0); invalid {
			goto INVALID
		}
		if minutes, invalid = pick(4, 0.0); invalid {
			goto INVALID
		}
		if seconds, invalid = pick(5, 0.0); invalid {
			goto INVALID
		}
		if ms, invalid = pick(6, 0.0); invalid {
			goto INVALID
		}

		if year >= 0 && year <= 99 {
			year += 1900
		}

		time := tme.Date(int(year), dateToGoMonth(int(month)), int(day), int(hours), int(minutes), int(seconds), int(ms) * 1000000, tme.UTC)
		return timeToEpoch(time)

	} else if len(argumentList) == 0 { // 0-argument
		time := tme.Now().UTC()
		return timeToEpoch(time)
	} else { // 1-argument
		value := valueOfArrayIndex(argumentList, 0)
		value = toPrimitive(value)
		if value.IsString() {
			// TODO Implement this
			goto INVALID
		}

		return toFloat(value)
	}

INVALID:
	epoch = math.NaN()
	return
}
