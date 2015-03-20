'use strict';

var kuler = require('./');

console.log('');
console.log('visual inspection');
console.log('');
console.log(kuler('red').style('red'));
console.log(kuler('black').style('#000'));
console.log(kuler('white').style('#FFFFFF'));
console.log(kuler('lime').style('AAFF5B'));
console.log(kuler('violet').style('violetred 1'));
console.log(kuler('purple').style('purple'));
console.log(kuler('purple').style('purple'), 'correctly reset to normal color');
console.log('');
console.log('alternate api');
console.log('');
console.log(kuler('green', 'green'));
