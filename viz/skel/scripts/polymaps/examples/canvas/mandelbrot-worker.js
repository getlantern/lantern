onmessage = function(e) {

  // following code adapted blindly from
  // http://blogs.msdn.com/mikeormond/archive/2008/08/22
  // /deep-zoom-multiscaletilesource-and-the-mandelbrot-set.aspx

  var tileCount = 1 << e.data.zoom;

  var ReStart = -2.0;
  var ReDiff = 3.0;

  var MinRe = ReStart + ReDiff * e.data.column / tileCount;
  var MaxRe = MinRe + ReDiff / tileCount;

  var ImStart = -1.2;
  var ImDiff = 2.4;

  var MinIm = ImStart + ImDiff * e.data.row / tileCount;
  var MaxIm = MinIm + ImDiff / tileCount;

  var Re_factor = (MaxRe - MinRe) / (e.data.size.x - 1);
  var Im_factor = (MaxIm - MinIm) / (e.data.size.y - 1);

  var MaxIterations = 32;

  var data = e.data.data = [];

  for (var y = 0, i = 0; y < e.data.size.y; ++y) {
    var c_im = MinIm + y * Im_factor;
    for (var x = 0; x < e.data.size.x; ++x) {
      var c_re = MinRe + x * Re_factor;
      var Z_re = c_re;
      var Z_im = c_im;
      var isInside = true;
      var n = 0;
      for (n = 0; n < MaxIterations; ++n) {
        var Z_re2 = Z_re * Z_re;
        var Z_im2 = Z_im * Z_im;
        if (Z_re2 + Z_im2 > 4) {
          isInside = false;
          break;
        }
        Z_im = 2 * Z_re * Z_im + c_im;
        Z_re = Z_re2 - Z_im2 + c_re;
      }
      if (isInside) {
        data[i++] = data[i++] = data[i++] = 0;
      } else if (n < MaxIterations / 2) {
        data[i++] = 255 / (MaxIterations / 2) * n;
        data[i++] = data[i++] = 0;
      } else {
        data[i++] = 255;
        data[i++] = data[i++] = (n - MaxIterations / 2) * 255 / (MaxIterations / 2);
      }
      data[i++] = 255;
    }
  }

  postMessage(e.data);
};
