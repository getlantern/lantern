/**
 * angular-ui-utils - Swiss-Army-Knife of AngularJS tools (with no external dependencies!)
 * @version v0.1.1 - 2014-02-05
 * @link http://angular-ui.github.com
 * @license MIT License, http://www.opensource.org/licenses/MIT
 */
!function(a,b){"use strict";var c=["ngInclude","ngPluralize","ngView","ngSwitch","uiCurrency","uiCodemirror","uiDate","uiEvent","uiKeypress","uiKeyup","uiKeydown","uiMask","uiMapInfoWindow","uiMapMarker","uiMapPolyline","uiMapPolygon","uiMapRectangle","uiMapCircle","uiMapGroundOverlay","uiModal","uiReset","uiScrollfix","uiSelect2","uiShow","uiHide","uiToggle","uiSortable","uiTinymce"];a.myCustomTags=a.myCustomTags||[],c.push.apply(c,a.myCustomTags);for(var d=function(a){var b=[],c=a.replace(/([A-Z])/g,function(a){return" "+a.toLowerCase()}),d=c.split(" ");if(1===d.length){var e=d[0];b.push(e),b.push("x-"+e),b.push("data-"+e)}else{var f=d[0],g=d.slice(1).join("-");b.push(f+":"+g),b.push(f+"-"+g),b.push("x-"+f+"-"+g),b.push("data-"+f+"-"+g)}return b},e=0,f=c.length;f>e;e++)for(var g=d(c[e]),h=0,i=g.length;i>h;h++){var j=g[h];b.createElement(j)}}(window,document);