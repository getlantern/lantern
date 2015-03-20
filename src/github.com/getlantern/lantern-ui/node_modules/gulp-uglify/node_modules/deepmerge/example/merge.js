var merge = require('../')
var x = { foo : { 'bar' : 3 } }
var y = { foo : { 'baz' : 4 }, quux : 5 }
var merged = merge(x, y)
console.dir(merged)
