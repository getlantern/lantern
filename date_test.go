package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestDate(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`Date`, "[function]")
	test(`new Date(0).toUTCString()`, "Thu, 01 Jan 1970 00:00:00 UTC")
	test(`new Date(1348616313).getTime()`, "1348616313")
	// TODO These shold be in local time
	test(`new Date(1348616313).toUTCString()`, "Fri, 16 Jan 1970 14:36:56 UTC")
	test(`abc = new Date(1348616313047); abc.toUTCString()`, "Tue, 25 Sep 2012 23:38:33 UTC")
	test(`abc.getFullYear()`, "2012")
	test(`abc.getUTCFullYear()`, "2012")
	test(`abc.getMonth()`, "8") // Remember, the JavaScript month is 0-based
	test(`abc.getUTCMonth()`, "8")
	test(`abc.getDate()`, "25")
	test(`abc.getUTCDate()`, "25")
	test(`abc.getDay()`, "2")
	test(`abc.getUTCDay()`, "2")
	test(`abc.getHours()`, "16")
	test(`abc.getUTCHours()`, "23")
	test(`abc.getMinutes()`, "38")
	test(`abc.getUTCMinutes()`, "38")
	test(`abc.getSeconds()`, "33")
	test(`abc.getUTCSeconds()`, "33")
	test(`abc.getMilliseconds()`, "47") // In honor of the 47%
	test(`abc.getUTCMilliseconds()`, "47")
	test(`abc.getTimezoneOffset()`, "420")
	if false {
		// TODO (When parsing is implemented)
		test(`new Date("Xyzzy").getTime()`, "NaN")
	}

	test(`abc.setFullYear(2011); abc.toUTCString()`, "Sun, 25 Sep 2011 23:38:33 UTC")
	test(`new Date(12564504e5).toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`new Date(2009, 9, 25).toUTCString()`, "Sun, 25 Oct 2009 00:00:00 UTC")
	test(`+(new Date(2009, 9, 25))`, "1256428800000")

	test(`abc = new Date(12564504e5); abc.setMilliseconds(2001); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:02 UTC")

	test(`abc = new Date(12564504e5); abc.setSeconds("61"); abc.toUTCString()`, "Sun, 25 Oct 2009 06:01:01 UTC")

	test(`abc = new Date(12564504e5); abc.setMinutes("61"); abc.toUTCString()`, "Sun, 25 Oct 2009 07:01:00 UTC")

	test(`abc = new Date(12564504e5); abc.setHours("5"); abc.toUTCString()`, "Sat, 24 Oct 2009 12:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setDate("26"); abc.toUTCString()`, "Tue, 27 Oct 2009 06:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setMonth(9); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`abc = new Date(12564504e5); abc.setMonth("09"); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`abc = new Date(12564504e5); abc.setMonth("10"); abc.toUTCString()`, "Wed, 25 Nov 2009 07:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setFullYear(2010); abc.toUTCString()`, "Mon, 25 Oct 2010 06:00:00 UTC")
}
