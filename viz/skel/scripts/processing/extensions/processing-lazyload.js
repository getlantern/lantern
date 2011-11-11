/*

    L A Z Y   L O A D I N G   F O R   P R O C E S S I N G . J S

    Part of the Processing.js project

    License       : MIT
    Web Site      : http://processingjs.org
    Github Repo.  : http://github.com/jeresig/processing-js
    Bug Tracking  : http://processing-js.lighthouseapp.com

*/
(function() {
  
  /**
   * Can we rely on there being a w3c DOM available?
   */
  var isDOMPresent = ("document" in this) && !("fake" in this.document);

  /**
   * If there is no DOM, don't run.
   */
  if (!isDOMPresent) {
    throw("This browser does not support the w3c DOM interface, which this extension for Processing.js relies on.");
  }

  /**
   * If there is no Processing.js, don't run.
   */
  if (!Processing) {
    throw("Please load Processing.js before loading the \"lazy loading\" extension.");
  }

  /**
   * Prevent processing from running its init function
   */
  Processing.disableInit();

  // constructor
  LazyLoading = this.LazyLoading = {};

  /**
   * This object will track every sketch that needs to be lazily loaded
   */
  var sketches = {};

  /**
   * Get all canvas elements on the page, and if they indicate that
   * they load processing sources, add them to our to-do collection/
   */
  var setSketches = function() {
    var elements = document.getElementsByTagName('canvas');
    var _id = 0;
    for (var e=0, end=elements.length; e<end; e++) {
      var canvas = elements[e];
      // make sure we only grab canvas elements that are associated with processing source files
      if (canvas.getAttribute("data-processing-sources") || canvas.getAttribute("data-src") || canvas.getAttribute("datasrc")) {
        if(!canvas.id) { canvas.id = "canvas"+(_id++); }
        var sketch = {};
        sketch.canvas = canvas;
        sketches[canvas.id] = sketch;
      }
    }
  };

  /**
   * This function sets the height values for the sketch's
   * canvas's top and bottom.
   * @param {sketch} sketch The sketch object for which the top/bottom values are set
   */
  var setHeightValues = function(sketch) {
    sketch.top = getElementPosition(sketch.canvas);
    sketch.bottom = sketch.top + sketch.canvas.clientHeight;
  }

  /**
   * General purpose "height of element on page" function.
   * @param {HTMLElement} element The HTML element for which the height on the page is being checked
   */
  var getElementPosition = function(element) {
    var height = 0;
    while (element && element.offsetTop) {
      height += element.offsetTop;
      element = element.parentNode;
    }
    return height;
  };

  /**
   * For each sketch in the to-do list, check whether it should be loaded
   * based on whether or not the user can see any part of the canvas it
   * is to be loaded in is visible on their screen.
   */
  var checkPositions = LazyLoading.checkPositions = function() {
    var top = 0, bottom = 0;
    for (s in sketches) {
      var sketch = sketches[s];
      top = window.pageYOffset;
      bottom = top + window.innerHeight;
      setHeightValues(sketch);
      if ((top <= sketch.top && sketch.top <= bottom) || (top <= sketch.bottom && sketch.bottom <= bottom)) {
        LazyLoading.loadSketch(sketch);
        delete sketches[s];
      }
    }
  };

  /**
   * Load the sketch associated with a canvas, from source indicated by that canvas.
   * @param {sketch} sketch An administrative sketch object
   */
  var loadSketch = LazyLoading.loadSketch = function(sketch) {
    if (sketch.canvas) {
      // form an array of which files must be loaded for this sketch
      var processingSources = sketch.canvas.getAttribute('data-processing-sources');
      if(processingSources===null) { processingSources = sketch.canvas.getAttribute('data-src'); }
      if(processingSources===null) { processingSources = sketch.canvas.getAttribute('datasrc'); }
      var filenames = processingSources.split(' ');
      for (var j = 0; j < filenames.length;) {
        if (filenames[j]) { j++; }
        else { filenames.splice(j, 1); }}
      // make Processing.js load this sketch into its canvas
      Processing.loadSketchFromSources(sketch.canvas, filenames);
    }
  };


  /**
   * In order for lazy-loading to do its work when it is started, it needs to first builds
   * the to-do list for sketches that may eventually need loading, then check whether
   * any of them need immediate loading, and finally, it needs to set up a scroll event
   * listener so that every time a user scrolls the page (in whichever way), the lazy
   * loader checks whether this resulted in one or more sketches needing to be loaded
   * because they have become visible to the user.
   */
  var init = function() {
    setSketches();
    checkPositions(); 
    document.addEventListener("scroll", LazyLoading.checkPositions, false);
  }


  /**
   * Finally, we kick-start the whole lazy loading process by making sure init() is called
   * when the document signals it has finished building the page's DOM.
   */
  document.addEventListener('DOMContentLoaded', init, false);
})();