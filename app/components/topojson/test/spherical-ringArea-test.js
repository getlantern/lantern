var vows = require("vows"),
    assert = require("assert"),
    spherical = require("../lib/topojson/spherical");

var suite = vows.describe("topojson.spherical.ringArea");

suite.addBatch({
  "ringArea": {
    topic: function() {
      return spherical.ringArea;
    },
    "small clockwise area": function(area) {
      assert.inDelta(area([[0, -.5], [0, .5], [1, .5], [1, -.5], [0, -.5]]), 0.0003046212, 1e-10);
    },
    "small counterclockwise area": function(area) {
      assert.inDelta(area([[0, -.5], [1, -.5], [1, .5], [0, .5], [0, -.5]]), -0.0003046212, 1e-10);
    },
    "large clockwise rectangle": function(area) {
      assert.inDelta(area([[-170, 80], [0, 80], [170, 80], [170, -80], [0, -80], [-170, -80], [-170, 80]]), 11.8575249632, 1e-10);
    }
  }
});

suite.export(module);
