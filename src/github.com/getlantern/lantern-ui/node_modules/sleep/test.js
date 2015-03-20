
var sleep = require('./');

console.log('sleeping for 1 seconds...');
sleep.sleep(1);
console.log('done');


console.log('sleeping for 2000000 microseconds (2 seconds)');
sleep.usleep(2000000);
console.log('done');

