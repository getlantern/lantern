var Binary = require('./binary_name.js').Binary;
var binary = new Binary({name:'node_sleep'});
var binding;
try {
  binding = require(binary.getRequirePath('Debug'));
} catch (err) { /* ignore */ }
if (!binding) {
  try {
    binding = require(binary.getRequirePath('Release'));
  } catch (err) { /* ignore */ }
}
if (!binding) {
  console.error("Using busy loop implementation of sleep.");
  binding = {
    sleep: function(s) {
      var e = new Date().getTime() + (s * 1000);

      while (new Date().getTime() <= e) {
        /* do nothing, but burn a lot of CPU while doing so */
        /* jshint noempty: false */
      }
    },

    usleep: function(s) {
      var e = new Date().getTime() + (s / 1000);

      while (new Date().getTime() <= e) {
        /* do nothing, but burn a lot of CPU while doing so */
        /* jshint noempty: false */
      }
    }
  };
}

module.exports = binding;
