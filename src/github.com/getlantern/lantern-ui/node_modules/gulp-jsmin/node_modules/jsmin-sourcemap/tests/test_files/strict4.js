'use strict';
var variable2 = 'value2';
function file2Function() {
console.log("clicked", variable2);
}
$("body").bind("click", file2Function);