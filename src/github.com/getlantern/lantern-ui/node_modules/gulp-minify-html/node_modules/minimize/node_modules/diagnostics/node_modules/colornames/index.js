/**
 * Module dependencies
 */
var colors = require('./colors')

var cssColors = colors.filter(function(color){
  return !! color.css
})

var vgaColors = colors.filter(function(color){
  return !! color.vga
})


/**
 * Get color value for a certain name.
 * @param name {String}
 * @return {String} Hex color value
 * @api public
 */

module.exports = function(name) {
  var color = module.exports.get(name)
  return color && color.value
}

/**
 * Get color object.
 *
 * @param name {String}
 * @return {Object} Color object
 * @api public
 */

module.exports.get = function(name) {
  name = name || ''
  name = name.trim()
  return colors.filter(function(color){
    return color.name === name
  }).pop()
}

/**
 * Get all color object.
 *
 * @return {Array}
 * @api public
 */

module.exports.all = module.exports.get.all = function() {
 return colors
}

/**
 * Get color object compatible with CSS.
 *
 * @return {Array}
 * @api public
 */

module.exports.get.css = function(name) {
  if (!name) return cssColors
  name = name || ''
  name = name.trim()
  return cssColors.filter(function(color){
    return color.name === name
  }).pop()
}



module.exports.get.vga = function(name) {
  if (!name) return vgaColors
  name = name || ''
  name = name.trim()
  return vgaColors.filter(function(color){
    return color.name === name
  }).pop()
}
