// we borrow some build system tooling from node-sqlite3
var package_json = require('./package.json');
var Binary = require('./lib/binary_name.js').Binary;
var util = require('./build-util/tools.js');

var cp = require('child_process');
var fs = require('fs');
var mkdirp = require('mkdirp');
var path = require('path');

var opts = {
    name: 'node_sleep',
    force: false,
    stage: false,
    configuration: 'Release',
    target_arch: process.arch,
    platform: process.platform,
    uri: 'http://node-sleep.s3.amazonaws.com/',
    tool: 'node-gyp',
    paths: {}
};

function log(msg) {
    console.log('['+package_json.name+']: ' + msg);
}

// only for dev
function log_debug(msg) {
    log(msg);
}

function done(err) {
    if (err) {
        log(err);
        process.exit(1);
    }
    process.exit(0);
}

function build(opts,callback) {
    var shell_cmd = opts.tool;
    if (opts.tool === 'node-gyp' && process.platform === 'win32') {
        shell_cmd = 'node-gyp.cmd';
    }
    var shell_args = ['rebuild'].concat(opts.args);
    var cmd = cp.spawn(shell_cmd,shell_args, {cwd: undefined, env: process.env, customFds: [ 0, 1, 2]});
    cmd.on('error', function (err) {
        if (err) {
            return callback(new Error("Failed to execute '" + shell_cmd + ' ' + shell_args.join(' ') + "' (" + err + ")"));
        }
    });
    // exit not close to support node v0.6.x
    cmd.on('exit', function (code) {
        if (code !== 0) {
            return callback(new Error("Failed to execute '" + shell_cmd + ' ' + shell_args.join(' ') + "' (" + code + ")"));
        }
        move(opts,callback);
    });
}

function move(opts,callback) {
    try {
        fs.statSync(opts.paths.build_module_path);
    } catch (ex) {
        return callback(new Error('Build succeeded but target not found at ' + opts.paths.build_module_path));
    }
    try {
        mkdirp.sync(path.dirname(opts.paths.runtime_module_path));
        log('Created: ' + path.dirname(opts.paths.runtime_module_path));
    } catch (err) {
        log_debug(err);
    }
    fs.renameSync(opts.paths.build_module_path,opts.paths.runtime_module_path);
    if (opts.stage) {
        try {
            mkdirp.sync(path.dirname(opts.paths.staged_module_file_name));
            log('Created: ' + path.dirname(opts.paths.staged_module_file_name));
        } catch (err) {
            log_debug(err);
        }
        fs.writeFileSync(opts.paths.staged_module_file_name,fs.readFileSync(opts.paths.runtime_module_path));
        // drop build metadata into build folder
        var metapath = path.join(path.dirname(opts.paths.staged_module_file_name),'build-info.json');
        // more build info
        opts.date = new Date();
        opts.node_features = process.features;
        opts.versions = process.versions;
        opts.config = process.config;
        opts.execPath = process.execPath;
        fs.writeFileSync(metapath,JSON.stringify(opts,null,2));
        //tarball(opts,callback);
        return callback();
    } else {
        log('Installed in ' + opts.paths.runtime_module_path + '');
        return callback();
    }
}

function rel(p) {
    return path.relative(process.cwd(),p);
}

// build it!
opts = util.parse_args(process.argv.slice(2), opts);
opts.binary = new Binary(opts);
var versioned = opts.binary.getRequirePath();
opts.paths.runtime_module_path = rel(path.join(__dirname, 'lib', versioned));
opts.paths.runtime_folder = rel(path.join(__dirname, 'lib', 'binding',opts.binary.configuration));
var staged_module_path = path.join(__dirname, 'stage', opts.binary.getModuleAbi(), opts.binary.getBasePath());
opts.paths.staged_module_file_name = rel(path.join(staged_module_path,opts.binary.filename()));
opts.paths.build_module_path = rel(path.join(__dirname, 'build', opts.binary.configuration, opts.binary.filename()));

build(opts, done);
