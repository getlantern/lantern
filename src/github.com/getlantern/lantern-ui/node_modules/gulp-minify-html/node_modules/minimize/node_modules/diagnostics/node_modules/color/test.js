var Color = require("./color");


var color = Color({ h : 0, s : 0, v : 100 });

console.log(color.hslString());


// color.hexString(); // #FFFFFF
// color.hue(100);
// color.hexString(); // #NANNANNAN

//var color = Color("#7743CE").rgb();

console.log(color.hexString());