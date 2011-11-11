// http://raphaeljs.com/icons/

var icons = (function(po) {
  return {
    marker: function() {
      var path = po.svg("path");
      path.setAttribute("transform", "translate(-16,-28)");
      path.setAttribute("d", "M16,3.5c-4.142,0-7.5,3.358-7.5,7.5c0,4.143,7.5,18.121,7.5,18.121S23.5,15.143,23.5,11C23.5,6.858,20.143,3.5,16,3.5z M16,14.584c-1.979,0-3.584-1.604-3.584-3.584S14.021,7.416,16,7.416S19.584,9.021,19.584,11S17.979,14.584,16,14.584z");
      return path;
    }
  };
})(org.polymaps);
