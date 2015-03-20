module.exports = function(name, files, tasks, push) {
  var through = require('through2');
  var concat = require('gulp-concat')(name, {newLine: require('os').EOL});

  /* PREPARE TASKS */
  tasks = tasks || [];

  var concatIndex = tasks.indexOf('concat');
  if (concatIndex == -1)
    tasks.unshift(concat);
  else
    tasks[concatIndex] = concat;

  tasks.push(through.obj(function(file, enc, streamCallback) {
    streamCallback(null, file);
    push(file);
  }));

  /* PREPARE TASKS END */

  var stream = through.obj(function(file, enc, streamCallback) {
    streamCallback(null, file);
  });
  var newStream = stream;
  tasks.forEach(function(task) {
    newStream = newStream.pipe(task);
  });

  files.forEach(stream.write.bind(stream));
  stream.end();
};
