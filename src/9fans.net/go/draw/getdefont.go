package draw

import "bytes"

func getdefont(d *Display) (*Subfont, error) {
	return d.readSubfont("*default*", bytes.NewReader(defontdata), nil)
}
