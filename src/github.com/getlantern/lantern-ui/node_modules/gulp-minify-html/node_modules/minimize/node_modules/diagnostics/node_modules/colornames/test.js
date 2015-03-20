var test = require('tape')

var toHex = require('./index.js')

test('maps VGA color names to HEX values', function(t) {
  t.plan(2)
  t.equal(toHex('red'), '#FF0000')
  t.equal(toHex('blue'), '#0000FF')
})

test('maps CSS color names to HEX values', function(t) {
  t.plan(2)
  t.equal(toHex('lightsalmon'), '#FFA07A')
  t.equal(toHex('mediumvioletred'), '#C71585')
})

test('meta data about a color', function(t) {
  t.plan(1)
  t.deepEqual(toHex.get('red'), {
    name: "red",
    css: true,
    value: "#FF0000",
    vga: true
  })
})

