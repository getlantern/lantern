var Color = require("../color"),
    assert = require("assert");

/*
runTest("construct", testConstruct);
runTest("convert", testConvert);
runTest("string", testString);
runTest("manipulations", testManip);
*/
runTest("luminosity", testLum);

function runTest(name, test) {
   console.time(name);
   for (var i = 0; i < 1000; i++) {
      test();
   }
   console.timeEnd(name);
}

function testConstruct() {
   assert.deepEqual(Color("#0A1E19").rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color("rgb(10, 30, 25)").rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color("rgba(10, 30, 25, 0.4)").rgb(), {r: 10, g: 30, b: 25, a: 0.4});
   assert.deepEqual(Color("rgb(4%, 12%, 10%)").rgb(), {r: 10, g: 31, b: 26});
   assert.deepEqual(Color("rgba(4%, 12%, 10%, 0.4)").rgb(), {r: 10, g: 31, b: 26, a: 0.4});
   assert.deepEqual(Color("blue").rgb(), {r: 0, g: 0, b: 255});
   assert.deepEqual(Color("hsl(120, 50%, 60%)").hsl(), {h: 120, s: 50, l: 60});
   assert.deepEqual(Color("hsla(120, 50%, 60%, 0.4)").hsl(), {h: 120, s: 50, l: 60, a: 0.4});
   assert.deepEqual(Color({r: 10, g: 30, b: 25}).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color({h: 10, s: 30, l: 25}).hsl(), {h: 10, s: 30, l: 25});
   assert.deepEqual(Color({h: 10, s: 30, v: 25}).hsv(), {h: 10, s: 30, v: 25});
   assert.deepEqual(Color({c: 10, m: 30, y: 25, k: 10}).cmyk(), {c: 10, m: 30, y: 25, k: 10});
   assert.deepEqual(Color({r: 10, g: 30, b: 25}).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color({r: 10, g: 30, b: 25, a: 0.4}).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
   assert.deepEqual(Color({red: 10, green: 30, blue: 25, alpha: 0.4}).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
   assert.deepEqual(Color({red: 10, green: 30, blue: 25}).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color({hue: 10, saturation: 30, lightness: 25}).hsl(), {h: 10, s: 30, l: 25});
   assert.deepEqual(Color({hue: 10, saturation: 30, value: 25}).hsv(), {h: 10, s: 30, v: 25});
   assert.deepEqual(Color({cyan: 10, magenta: 30, yellow: 25, black: 10}).cmyk(), {c: 10, m: 30, y: 25, k: 10});
   assert.deepEqual(Color().rgb(10, 30, 25).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color().rgb(10, 30, 25, 0.4).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
   assert.deepEqual(Color().rgb([10, 30, 25]).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color().rgb([10, 30, 25, 0.4]).rgb(), {r: 10, g: 30, b: 25, a: 0.4});
   assert.deepEqual(Color().hsl([360, 10, 10]).hsl(), {h: 360, s: 10, l: 10});
   assert.deepEqual(Color().hsv([360, 10, 10]).hsv(), {h: 360, s: 10, v: 10});
   assert.deepEqual(Color().cmyk([10, 10, 10, 10]).cmyk(), {c: 10, m: 10, y: 10, k: 10});
   assert.deepEqual(Color().rgb(10, 30, 25).rgb(), {r: 10, g: 30, b: 25});
   assert.deepEqual(Color({r: 10, g: 20, b: 30}).rgbArray(), [10, 20, 30]);
}

function testConvert() {
   assert.equal(Color({r: 10, g: 20, b: 30, a: 0.4}).alpha(0.7).alpha(), 0.7);
   assert.deepEqual(Color({r: 0, g: 0, b: 0}).red(50).green(50).hsv(), {h: 60, s: 100, v: 20});
}

function testString() {
   assert.equal(Color("rgb(10, 30, 25)").hexString(), "#0A1E19")
   assert.equal(Color("rgb(0, 0, 255)").keyword(), "blue");   
}

function testLum() {
   assert.equal(Color("white").luminosity(), 1);
   assert.equal(Color("white").contrast(Color("black")), 21);
   assert.ok(Color("red").dark());
}

function testManip() {
   assert.deepEqual(Color({r: 67, g: 122, b: 134}).greyscale().rgb(), {r: 107, g: 107, b: 107});
   assert.deepEqual(Color("yellow").mix(Color("cyan")).rgbArray(), [128, 255, 128]);   
}
