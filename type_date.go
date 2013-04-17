package otto

import (
	"fmt"
	"math"
	"regexp"
	Time "time"
)

type _dateObject struct {
	time  Time.Time // Time from the "time" package, a cached version of time
	epoch int64
	value Value
	isNaN bool
}

type _ecmaTime struct {
	year        int
	month       int
	day         int
	hour        int
	minute      int
	second      int
	millisecond int
	location    *Time.Location // Basically, either local or UTC
}

func ecmaTime(goTime Time.Time) _ecmaTime {
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

func (self *_ecmaTime) goTime() Time.Time {
	return Time.Date(
		self.year,
		dateToGoMonth(self.month),
		self.day,
		self.hour,
		self.minute,
		self.second,
		self.millisecond*(100*100*100),
		self.location,
	)
}

func (self *_dateObject) Time() Time.Time {
	return self.time
}

func (self *_dateObject) Epoch() int64 {
	return self.epoch
}

func (self *_dateObject) Value() Value {
	return self.value
}

func (self *_dateObject) SetNaN() {
	self.time = Time.Time{}
	self.epoch = -1
	self.value = NaNValue()
	self.isNaN = true
}

func (self *_dateObject) SetTime(time Time.Time) {
	self.Set(timeToEpoch(time))
}

func (self *_dateObject) Set(epoch float64) {
	// epoch
	self.epoch = epochToInteger(epoch)

	// time
	time, err := epochToTime(epoch)
	self.time = time // Is either a valid time, or the zero-value for time.Time

	// value & isNaN
	if err != nil {
		self.isNaN = true
		self.epoch = -1
		self.value = NaNValue()
	} else {
		self.value = toValue(self.epoch)
	}
}

func epochToInteger(value float64) int64 {
	if value > 0 {
		return int64(math.Floor(value))
	}
	return int64(math.Ceil(value))
}

func epochToTime(value float64) (time Time.Time, err error) {
	epochWithMilli := value
	if math.IsNaN(epochWithMilli) || math.IsInf(epochWithMilli, 0) {
		err = fmt.Errorf("Invalid time %v", value)
		return
	}

	epoch := int64(epochWithMilli / 1000)
	milli := int64(epochWithMilli) % 1000

	time = Time.Unix(int64(epoch), milli*1000000).UTC()
	return
}

func timeToEpoch(time Time.Time) float64 {
	return float64(time.Unix()*1000 + int64(time.Nanosecond()/1000000))
}

func (runtime *_runtime) newDateObject(epoch float64) *_object {
	self := runtime.newObject()
	self.class = "Date"

	// TODO Fix this, redundant arguments, etc.
	self._Date = &_dateObject{}
	self._Date.Set(epoch)
	return self
}

func dateObjectOf(_dateObject *_object) *_dateObject {
	if _dateObject == nil || _dateObject.class != "Date" {
		panic(newTypeError())
	}
	return _dateObject._Date
}

// JavaScript is 0-based, Go is 1-based (15.9.1.4)
func dateToGoMonth(month int) Time.Month {
	return Time.Month(month + 1)
}

func dateFromGoMonth(month Time.Month) int {
	return int(month) - 1
}

// Both JavaScript & Go are 0-based (Sunday == 0)
func dateToGoDay(day int) Time.Weekday {
	return Time.Weekday(day)
}

func dateFromGoDay(day Time.Weekday) int {
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
		var year, month, day, hour, minute, second, millisecond float64
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
		if hour, invalid = pick(3, 0.0); invalid {
			goto INVALID
		}
		if minute, invalid = pick(4, 0.0); invalid {
			goto INVALID
		}
		if second, invalid = pick(5, 0.0); invalid {
			goto INVALID
		}
		if millisecond, invalid = pick(6, 0.0); invalid {
			goto INVALID
		}

		if year >= 0 && year <= 99 {
			year += 1900
		}

		time := Time.Date(int(year), dateToGoMonth(int(month)), int(day), int(hour), int(minute), int(second), int(millisecond)*1000*1000, Time.UTC)
		return timeToEpoch(time)

	} else if len(argumentList) == 0 { // 0-argument
		time := Time.Now().UTC()
		return timeToEpoch(time)
	} else { // 1-argument
		value := valueOfArrayIndex(argumentList, 0)
		value = toPrimitive(value)
		if value.IsString() {
			return dateParse(toString(value))
		}

		return toFloat(value)
	}

INVALID:
	epoch = math.NaN()
	return
}

var (
	dateLayoutList = []string{
		"2006",
		"2006-01",
		"2006-01-02",

		"2006T15:04",
		"2006-01T15:04",
		"2006-01-02T15:04",

		"2006T15:04:05",
		"2006-01T15:04:05",
		"2006-01-02T15:04:05",

		"2006T15:04:05.000",
		"2006-01T15:04:05.000",
		"2006-01-02T15:04:05.000",

		"2006T15:04-0700",
		"2006-01T15:04-0700",
		"2006-01-02T15:04-0700",

		"2006T15:04:05-0700",
		"2006-01T15:04:05-0700",
		"2006-01-02T15:04:05-0700",

		"2006T15:04:05.000-0700",
		"2006-01T15:04:05.000-0700",
		"2006-01-02T15:04:05.000-0700",
	}
	matchDateTimeZone = regexp.MustCompile(`^(.*)(?:(Z)|([\+\-]\d{2}):(\d{2}))$`)
)

func dateParse(date string) (epoch float64) {
	// YYYY-MM-DDTHH:mm:ss.sssZ
	var time Time.Time
	var err error
	{
		date := date
		if match := matchDateTimeZone.FindStringSubmatch(date); match != nil {
			if match[2] == "Z" {
				date = match[1] + "+0000"
			} else {
				date = match[1] + match[3] + match[4]
			}
		}
		for _, layout := range dateLayoutList {
			time, err = Time.Parse(layout, date)
			if err == nil {
				break
			}
		}
	}
	if err != nil {
		dbg(err)
		return math.NaN()
	}
	return float64(time.UnixNano()) / (1000 * 1000) // UnixMilli()
}
