# colornames

Convert color names to HEX color values.

[![NPM](https://nodei.co/npm/colornames.png)](https://nodei.co/npm/colornames/)

[![Build Status](https://travis-ci.org/timoxley/colornames.png?branch=master)](https://travis-ci.org/timoxley/colornames)
[![Dependency Status](https://david-dm.org/timoxley/colornames.png)](https://david-dm.org/timoxley/colornames)



## Installation

    $ component install timoxley/colornames

## Example

```js
var toHex = require('colornames')
```

### VGA color names
```js
toHex('red') // => "#FF0000"
toHex('blue') // => "#0000FF"
```

### CSS color names
```js
toHex('lightsalmon') // => "#FFA07A"
toHex('mediumvioletred') // => "#C71585"
```

### Get meta data about a color
```js
toHex.get('red')
// =>
{
  name: "red",
  css: true,
  value: "#FF0000",
  vga: true
}
```

## API

### colornames(name)
Get HEX code for a color name, or `undefined` if unknown.

### .get(name)
All known data about color, including whether valid VGA or CSS color
name.

### .get.vga(name)
HEX code for a color name, only if the color is a valid VGA color
name.

### .get.css(name)
HEX code for a color name, only if the color is a valid CSS color
name.

###.all()
Get all color names data.

## License

  MIT

## Complete Color Map

![example-color-table-](https://f.cloud.github.com/assets/43438/643981/f57948a0-d381-11e2-99fd-197c44065564.png)
