'use strict';
var variable1 = 'value1';
function file1Function() {
console.log("clicked", variable1);
}
$("body").bind("click", file1Function);