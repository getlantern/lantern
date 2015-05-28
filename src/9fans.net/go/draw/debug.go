package draw

// SetDebug enables debugging for the remote devdraw server.
func (d *Display) SetDebug(debug bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	a := d.bufimage(2)
	a[0] = 'D'
	a[1] = 0
	if debug {
		a[1] = 1
	}
}
