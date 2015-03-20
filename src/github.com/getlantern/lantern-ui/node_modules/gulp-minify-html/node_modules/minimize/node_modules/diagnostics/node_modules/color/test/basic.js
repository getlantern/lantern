var Color = require("../color"),
    assert = require("assert");

// Color() instance
assert.equal(new Color("red").red(), 255);

assert.ok((new Color) instanceof Color);

// Color() argument
assert.deepEqual(Color("#0A1E19").rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color("rgb(10, 30, 25)").rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color("rgba(10, 30, 25, 0.4)").rgb(), {r: 10, g: 30, b: 25, a: 0.4});
assert.deepEqual(Color("rgb(4%, 12%, 10%)").rgb(), {r: 10, g: 31, b: 26});
assert.deepEqual(Color("rgba(4%, 12%, 10%, 0.4)").rgb(), {r: 10, g: 31, b: 26, a: 0.4});
assert.deepEqual(Color("blue").rgb(), {r: 0, g: 0, b: 255});
assert.deepEqual(Color("hsl(120, 50%, 60%)").hsl(), {h: 120, s: 50, l: 60});
assert.deepEqual(Color("hsla(120, 50%, 60%, 0.4)").hsl(), {h: 120, s: 50, l: 60, a: 0.4});
assert.deepEqual(Color("hwb(120, 50%, 60%)").hwb(), {h: 120, w: 50, b: 60});
assert.deepEqual(Color("hwb(120, 50%, 60%, 0.4)").hwb(), {h: 120, w: 50, b: 60, a: 0.4});

assert.deepEqual(Color({r: 10, g: 30, b: 25}).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color({h: 10, s: 30, l: 25}).hsl(), {h: 10, s: 30, l: 25});
assert.deepEqual(Color({h: 10, s: 30, v: 25}).hsv(), {h: 10, s: 30, v: 25});
assert.deepEqual(Color({h: 10, w: 30, b: 25}).hwb(), {h: 10, w: 30, b: 25});
assert.deepEqual(Color({c: 10, m: 30, y: 25, k: 10}).cmyk(), {c: 10, m: 30, y: 25, k: 10});

assert.deepEqual(Color({red: 10, green: 30, blue: 25}).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color({hue: 10, saturation: 30, lightness: 25}).hsl(), {h: 10, s: 30, l: 25});
assert.deepEqual(Color({hue: 10, saturation: 30, value: 25}).hsv(), {h: 10, s: 30, v: 25});
assert.deepEqual(Color({hue: 10, whiteness: 30, blackness: 25}).hwb(), {h: 10, w: 30, b: 25});
assert.deepEqual(Color({cyan: 10, magenta: 30, yellow: 25, black: 10}).cmyk(), {c: 10, m: 30, y: 25, k: 10});

// Setters
assert.deepEqual(Color().rgb(10, 30, 25).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color().rgb(10, 30, 25, 0.4).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
assert.deepEqual(Color().rgb([10, 30, 25]).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color().rgb([10, 30, 25, 0.4]).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
assert.deepEqual(Color().rgb({r: 10, g: 30, b: 25}).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color().rgb({r: 10, g: 30, b: 25, a: 0.4}).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
assert.deepEqual(Color().rgb({red: 10, green: 30, blue: 25}).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color().rgb({red: 10, green: 30, blue: 25, alpha: 0.4}).rgb(), {r: 10, g: 30, b: 25, a: 0.4});

assert.deepEqual(Color().hsl([260, 10, 10]).hsl(), {h: 260, s: 10, l: 10});
assert.deepEqual(Color().hsv([260, 10, 10]).hsv(), {h: 260, s: 10, v: 10});
assert.deepEqual(Color().hwb([260, 10, 10]).hwb(), {h: 260, w: 10, b: 10});
assert.deepEqual(Color().cmyk([10, 10, 10, 10]).cmyk(), {c: 10, m: 10, y: 10, k: 10});

// retain alpha
assert.equal(Color().rgb([10, 30, 25, 0.4]).rgb([10, 30, 25]).alpha(), 0.4);

// Translations
assert.deepEqual(Color().rgb(10, 30, 25).rgb(), {r: 10, g: 30, b: 25});
assert.deepEqual(Color().rgb(10, 30, 25).hsl(), {h: 165, s: 50, l: 8});
assert.deepEqual(Color().rgb(10, 30, 25).hsv(), {h: 165, s: 67, v: 12});
assert.deepEqual(Color().rgb(10, 30, 25).hwb(), {h: 165, w: 4, b: 88});
assert.deepEqual(Color().rgb(10, 30, 25).cmyk(), {c: 67, m: 0, y: 17, k: 88});

// Array getters
assert.deepEqual(Color({r: 10, g: 20, b: 30}).rgbArray(), [10, 20, 30]);
assert.deepEqual(Color({h: 10, s: 20, l: 30}).hslArray(), [10, 20, 30]);
assert.deepEqual(Color({h: 10, s: 20, v: 30}).hsvArray(), [10, 20, 30]);
assert.deepEqual(Color({h: 10, w: 20, b: 30}).hwbArray(), [10, 20, 30]);
assert.deepEqual(Color({c: 10, m: 20, y: 30, k: 40}).cmykArray(), [10, 20, 30, 40]);

// Multiple times
var color = Color({r: 10, g: 20, b: 30});
assert.deepEqual(color.rgbaArray(), [10, 20, 30, 1]);
assert.deepEqual(color.rgbaArray(), [10, 20, 30, 1]);

// Channel getters/setters
assert.equal(Color({r: 10, g: 20, b: 30, a: 0.4}).alpha(), 0.4);
assert.equal(Color({r: 10, g: 20, b: 30, a: 0.4}).alpha(0.7).alpha(), 0.7);
assert.equal(Color({r: 10, g: 20, b: 30}).red(), 10);
assert.equal(Color({r: 10, g: 20, b: 30}).red(100).red(), 100);
assert.equal(Color({r: 10, g: 20, b: 30}).green(), 20);
assert.equal(Color({r: 10, g: 20, b: 30}).green(200).green(), 200);
assert.equal(Color({r: 10, g: 20, b: 30}).blue(), 30);
assert.equal(Color({r: 10, g: 20, b: 30}).blue(60).blue(), 60);
assert.equal(Color({h: 10, s: 20, l: 30}).hue(), 10);
assert.equal(Color({h: 10, s: 20, l: 30}).hue(100).hue(), 100);
assert.equal(Color({h: 10, w: 20, b: 30}).hue(), 10);
assert.equal(Color({h: 10, w: 20, b: 30}).hue(100).hue(), 100);

// Capping values
assert.equal(Color({h: 400, s: 50, l: 10}).hue(), 360);
assert.equal(Color({h: 100, s: 50, l: 80}).lighten(0.5).lightness(), 100);
assert.equal(Color({h: -400, s: 50, l: 10}).hue(), 0);

assert.equal(Color({h: 400, w: 50, b: 10}).hue(), 0); // 0 == 360
assert.equal(Color({h: 100, w: 50, b: 80}).blacken(0.5).blackness(), 100);
assert.equal(Color({h: -400, w: 50, b: 10}).hue(), 0);

assert.equal(Color().red(400).red(), 255);
assert.equal(Color().red(-400).red(), 0);
assert.equal(Color().rgb(10, 10, 10, 12).alpha(), 1);
assert.equal(Color().rgb(10, 10, 10, -200).alpha(), 0);
assert.equal(Color().alpha(-12).alpha(), 0);
assert.equal(Color().alpha(3).alpha(), 1);

// Translate with channel setters
assert.deepEqual(Color({r: 0, g: 0, b: 0}).lightness(50).hsl(), {h: 0, s: 0, l: 50});
assert.deepEqual(Color({r: 0, g: 0, b: 0}).red(50).green(50).hsv(), {h: 60, s: 100, v: 20});

// CSS String getters
assert.equal(Color("rgb(10, 30, 25)").hexString(), "#0A1E19")
assert.equal(Color("rgb(10, 30, 25)").rgbString(), "rgb(10, 30, 25)")
assert.equal(Color("rgb(10, 30, 25, 0.4)").rgbString(), "rgba(10, 30, 25, 0.4)")
assert.equal(Color("rgb(10, 30, 25)").percentString(), "rgb(4%, 12%, 10%)")
assert.equal(Color("rgb(10, 30, 25, 0.3)").percentString(), "rgba(4%, 12%, 10%, 0.3)")
assert.equal(Color("rgb(10, 30, 25)").hslString(), "hsl(165, 50%, 8%)")
assert.equal(Color("rgb(10, 30, 25, 0.3)").hslString(), "hsla(165, 50%, 8%, 0.3)")
assert.equal(Color("rgb(10, 30, 25)").hwbString(), "hwb(165, 4%, 88%)")
assert.equal(Color("rgb(10, 30, 25, 0.3)").hwbString(), "hwb(165, 4%, 88%, 0.3)")
assert.equal(Color("rgb(0, 0, 255)").keyword(), "blue")
assert.strictEqual(Color("rgb(10, 30, 25)").keyword(), undefined)

// Number getters
assert.equal(Color("rgb(10, 30, 25)").rgbNumber(), 0xA1E19)

// luminosity, etc.
assert.equal(Color("white").luminosity(), 1);
assert.equal(Color("black").luminosity(), 0);
assert.equal(Color("red").luminosity(), 0.2126);
assert.equal(Color("white").contrast(Color("black")), 21);
assert.equal(Math.round(Color("white").contrast(Color("red"))), 4);
assert.equal(Math.round(Color("red").contrast(Color("white"))), 4);
assert.equal(Color("blue").contrast(Color("blue")), 1);
assert.ok(Color("black").dark());
assert.ok(!Color("black").light());
assert.ok(Color("white").light());
assert.ok(!Color("white").dark());
assert.ok(Color("blue").dark());
assert.ok(Color("darkgreen").dark());
assert.ok(Color("pink").light());
assert.ok(Color("goldenrod").light());
assert.ok(Color("red").dark());

// Manipulators
assert.deepEqual(Color({r: 67, g: 122, b: 134}).greyscale().rgb(), {r: 107, g: 107, b: 107});
assert.deepEqual(Color({r: 67, g: 122, b: 134}).negate().rgb(), {r: 188, g: 133, b: 121});
assert.equal(Color({h: 100, s: 50, l: 60}).lighten(0.5).lightness(), 90);
assert.equal(Color({h: 100, s: 50, l: 60}).darken(0.5).lightness(), 30);
assert.equal(Color({h: 100, w: 50, b: 60}).whiten(0.5).whiteness(), 75);
assert.equal(Color({h: 100, w: 50, b: 60}).blacken(0.5).blackness(), 90);
assert.equal(Color({h: 100, s: 40, l: 50}).saturate(0.5).saturation(), 60);
assert.equal(Color({h: 100, s: 80, l: 60}).desaturate(0.5).saturation(), 40);
assert.equal(Color({r: 10, g: 10, b: 10, a: 0.8}).clearer(0.5).alpha(), 0.4);
assert.equal(Color({r: 10, g: 10, b: 10, a: 0.5}).opaquer(0.5).alpha(), 0.75);
assert.equal(Color({h: 60, s: 0, l: 0}).rotate(180).hue(), 240);
assert.equal(Color({h: 60, s: 0, l: 0}).rotate(-180).hue(), 240);

assert.deepEqual(Color("yellow").mix(Color("cyan")).rgbArray(), [128, 255, 128]);
assert.deepEqual(Color("yellow").mix(Color("grey")).rgbArray(), [192, 192, 64]);
assert.deepEqual(Color("yellow").mix(Color("grey"), 1).rgbArray(), [128, 128, 128]);
assert.deepEqual(Color("yellow").mix(Color("grey"), 0.8).rgbArray(), [153, 153, 102]);
assert.deepEqual(Color("yellow").mix(Color("grey").alpha(0.5)).rgbaArray(), [223, 223, 32, 0.75]);

// Clone
var clone = Color({r: 10, g: 20, b: 30});
assert.deepEqual(clone.rgbaArray(), [10, 20, 30, 1]);
assert.deepEqual(clone.clone().rgb(50, 40, 30).rgbaArray(), [50, 40, 30, 1]);
assert.deepEqual(clone.rgbaArray(), [10, 20, 30, 1]);

// Level
assert.equal(Color("white").level(Color("black")), "AAA");
assert.equal(Color("grey").level(Color("black")), "AA");

// Exceptions
assert.throws(function () {
  Color("unknow")
}, /Unable to parse color from string/);

assert.throws(function () {
  Color({})
}, /Unable to parse color from object/);
