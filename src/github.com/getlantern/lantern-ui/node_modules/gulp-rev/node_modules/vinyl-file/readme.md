# vinyl-file [![Build Status](https://travis-ci.org/sindresorhus/vinyl-file.svg?branch=master)](https://travis-ci.org/sindresorhus/vinyl-file)

> Create a [vinyl file](https://github.com/wearefractal/vinyl) from an actual file


## Install

```sh
$ npm install --save vinyl-file
```


## Usage

```js
var vinylFile = require('vinyl-file');

var file = vinylFile.readSync('index.js');

console.log(file.path);
//=> /Users/sindresorhus/dev/vinyl-file/index.js

console.log(file.cwd);
//=> /Users/sindresorhus/dev/vinyl-file
```


## API

### read(path, [options], callback)

Create a vinyl file and pass it to the callback.

### readSync(path, [options])

Create a vinyl file synchronously and return it.

#### options

##### base

Type: `string`  
Default: `process.cwd()`

Override the `base` of the vinyl file.

##### cwd

Type: `string`  
Default: `process.cwd()`

Override the `cwd` (current working directory) of the vinyl file.

##### buffer

Type: `boolean`  
Default: `true`

Setting this to `false` will return `file.contents` as a stream. This is useful when working with large files. **Note:** Plugins might not implement support for streams.

##### read

Type: `boolean`  
Default: `true`

Setting this to `false` will return `file.contents` as null and not read the file at all.


## License

MIT © [Sindre Sorhus](http://sindresorhus.com)
