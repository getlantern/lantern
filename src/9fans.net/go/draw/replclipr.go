package draw

import "image"

// ReplClipr sets the replication boolean and clip rectangle for the specified image.
func (dst *Image) ReplClipr(repl bool, clipr image.Rectangle) {
	dst.Display.mu.Lock()
	defer dst.Display.mu.Unlock()
	b := dst.Display.bufimage(22)
	b[0] = 'c'
	bplong(b[1:], uint32(dst.id))
	byteRepl := byte(0)
	if repl {
		byteRepl = 1
	}
	b[5] = byteRepl
	bplong(b[6:], uint32(clipr.Min.X))
	bplong(b[10:], uint32(clipr.Min.Y))
	bplong(b[14:], uint32(clipr.Max.X))
	bplong(b[18:], uint32(clipr.Max.Y))
	dst.Repl = repl
	dst.Clipr = clipr
}
