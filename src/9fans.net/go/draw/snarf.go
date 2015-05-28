package draw

// ReadSnarf reads the snarf buffer into buf, returning the number of bytes read,
// the total size of the snarf buffer (useful if buf is too short), and any
// error. No error is returned if there is no problem except for buf being too
// short.
func (d *Display) ReadSnarf(buf []byte) (int, int, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	n, actual, err := d.conn.ReadSnarf(buf)
	if err != nil {
		return 0, 0, err
	}
	return n, actual, nil
}

// WriteSnarf writes the data to the snarf buffer.
func (d *Display) WriteSnarf(data []byte) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	err := d.conn.WriteSnarf(data)
	if err != nil {
		return err
	}
	return nil
}
