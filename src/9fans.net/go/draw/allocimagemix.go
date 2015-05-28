package draw

import "image"

// AllocImageMix blends the two colors to create a tiled image representing
// their combination. For pixel formats of 8 bits or less, it creates a 2x2
// pixel texture whose average value is the mix. Otherwise it creates a 1-pixel
// solid color blended using 50% alpha for each.
func (d *Display) AllocImageMix(color1, color3 Color) *Image {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.ScreenImage.Depth <= 8 { // create a 2x2 texture
		t, _ := d.allocImage(image.Rect(0, 0, 1, 1), d.ScreenImage.Pix, false, color1)
		b, _ := d.allocImage(image.Rect(0, 0, 2, 2), d.ScreenImage.Pix, true, color3)
		b.draw(image.Rect(0, 0, 1, 1), t, nil, image.ZP)
		t.free()
		return b
	}

	// use a solid color, blended using alpha
	if d.qmask == nil {
		d.qmask, _ = d.allocImage(image.Rect(0, 0, 1, 1), GREY8, true, 0x3F3F3FFF)
	}
	t, _ := d.allocImage(image.Rect(0, 0, 1, 1), d.ScreenImage.Pix, true, color1)
	b, _ := d.allocImage(image.Rect(0, 0, 1, 1), d.ScreenImage.Pix, true, color3)
	b.draw(b.R, t, d.qmask, image.ZP)
	t.free()
	return b
}
