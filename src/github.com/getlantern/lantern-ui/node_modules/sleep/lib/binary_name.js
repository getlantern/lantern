
var path = require('path');

var Binary = function(options) {
  options = options || {};
  var package_json = options.package_json || require('../package.json');
  this.name = options.name || 'binding';
  this.configuration = options.configuration || 'Release';
  this.uri = options.uri || 'http://'+this.name+'.s3.amazonaws.com/';
  this.module_maj_min = package_json.version.split('.').slice(0,2).join('.');
  this.module_abi = package_json.abi;
  this.platform = options.platform || process.platform;
  this.target_arch = options.target_arch || process.arch;
  if (process.versions.modules) {
    // added in >= v0.10.4 and v0.11.7
    // https://github.com/joyent/node/commit/ccabd4a6fa8a6eb79d29bc3bbe9fe2b6531c2d8e
    this.node_abi = 'node-v' + (+process.versions.modules);
  } else {
    this.node_abi = 'v8-' + process.versions.v8.split('.').slice(0,2).join('.');
  }
};

Binary.prototype.filename = function() {
    return this.name + '.node';
};

Binary.prototype.compression = function() {
    return '.tar.gz';
};

Binary.prototype.getBasePath = function() {
    return this.node_abi +
           '-' + this.platform +
           '-' + this.target_arch;
};

Binary.prototype.getRequirePath = function(configuration) {
    return './' + path.join('binding',
        configuration || this.configuration,
        this.getBasePath(),
        this.filename());
};

Binary.prototype.getModuleAbi = function() {
    return this.name + '-v' + this.module_maj_min + '.' + this.module_abi;
};

Binary.prototype.getArchivePath = function() {
    return this.getModuleAbi() +
           '-' +
           this.getBasePath() +
           this.compression();
};

Binary.prototype.getRemotePath = function() {
    return this.uri+this.configuration+'/'+this.getArchivePath();
};

module.exports.Binary = Binary;
