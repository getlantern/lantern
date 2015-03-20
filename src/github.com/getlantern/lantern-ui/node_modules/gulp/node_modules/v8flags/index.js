const os = require('os');
const fs = require('fs');
const path = require('path');
const execFile = require('child_process').execFile;

const tmpfile = path.join(os.tmpdir(), process.versions.v8+'.flags.json');
const exclusions = ['--help'];

module.exports = function (cb) {
  try {
    var flags = require(tmpfile);
    process.nextTick(function(){
      cb(null, flags);
    });
  } catch (e) {
    execFile(process.execPath, ['--v8-options'], function (execErr, result) {
      var flags;
      if (execErr) {
        return cb(execErr);
      }
      flags = result.match(/\s\s--(\w+)/gm).map(function (match) {
        return match.substring(2);
      }).filter(function (name) {
        return exclusions.indexOf(name) === -1;
      });
      fs.writeFile(tmpfile, JSON.stringify(flags), { encoding:'utf8' },
        function (writeErr) {
          if (writeErr) {
            return cb(writeErr);
          }
          cb(null, flags);
        }
      );
    });
  }
};
