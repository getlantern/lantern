var Color = require("../color");

var color = Color("#77E4FE");

color.red(120).lighten(.5);

console.log(color.hslString());