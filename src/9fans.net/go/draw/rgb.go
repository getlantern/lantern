package draw

/*
 * This original version, although fast and a true inverse of
 * cmap2rgb, in the sense that rgb2cmap(cmap2rgb(c))
 * returned the original color, does a terrible job for RGB
 * triples that do not appear in the color map, so it has been
 * replaced by the much slower version below, that loops
 * over the color map looking for the nearest point in RGB
 * space.  There is no visual psychology reason for that
 * criterion, but it's easy to implement and the results are
 * far more pleasing.
 *
int
rgb2cmap(int cr, int cg, int cb)
{
	int r, g, b, v, cv;

	if(cr < 0)
		cr = 0;
	else if(cr > 255)
		cr = 255;
	if(cg < 0)
		cg = 0;
	else if(cg > 255)
		cg = 255;
	if(cb < 0)
		cb = 0;
	else if(cb > 255)
		cb = 255;
	r = cr>>6;
	g = cg>>6;
	b = cb>>6;
	cv = cr;
	if(cg > cv)
		cv = cg;
	if(cb > cv)
		cv = cb;
	v = (cv>>4)&3;
	return ((((r<<2)+v)<<4)+(((g<<2)+b+v-r)&15));
}
*/

func rgb2cmap(cr, cg, cb int) int {
	best := 0
	bestsq := 0x7FFFFFFF
	for i := 0; i < 256; i++ {
		r, g, b := cmap2rgb(i)
		sq := (r-cr)*(r-cr) + (g-cg)*(g-cg) + (b-cb)*(b-cb)
		if sq < bestsq {
			bestsq = sq
			best = i
		}
	}
	return best
}

func cmap2rgb(c int) (r, g, b int) {
	r = c >> 6
	v := (c >> 4) & 3
	j := (c - v + r) & 15
	g = j >> 2
	b = j & 3
	den := r
	if g > den {
		den = g
	}
	if b > den {
		den = b
	}
	if den == 0 {
		v *= 17
		return v, v, v
	}
	num := 17 * (4*den + v)
	r = r * num / den
	g = g * num / den
	b = b * num / den
	return
}

func cmap2rgba(c int) Color {
	r, g, b := cmap2rgb(c)
	return Color(r<<24 | g<<16 | b<<8 | 0xFF)
}
