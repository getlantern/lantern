var http = require('http');
var url = require('url');

function download(from,options,callback) {
    options = options || {};
    var uri = url.parse(from);
    var req = http.request(uri);
    req.on('response', function(res){
        // needed for end to be called
        res.resume();
        if (res.statusCode !== 200) {
            return callback(new Error('Server returned '+ res.statusCode));
        }
        function returnBuffer() {
            // todo - use http://nodejs.org/api/buffer.html#buffer_class_method_buffer_concat_list_totallength
            for (var length = 0, i = 0; i < out.length; ++i) {
                length += out[i].length;
            }
            var result = new Buffer(length);
            for (var pos = 0, j = 0; j < out.length; ++j) {
                out[j].copy(result, pos);
                pos += out[j].length;
            }
            return callback(null,result);
        }
        var out = [];
        res.on('data', function(chunk) {
            out.push(chunk);
        });
        res.on('end', function(){
            returnBuffer();
        });
        res.on('close', function(){
            returnBuffer();
        });
    });
    req.on('error', function(err){
        callback(err);
    });
    req.end();
}


function parse_args(_args, opts) {
    // first split them like npm returns
    var args = [], next_arg;
    _args.forEach(function(a) {
        var parts = a.split('=');
        parts.forEach(function(p) {
            args.push(p);
        });
    });
    // respect flags passed to npm install
    if (process.env.npm_config_argv) {
        var argv_obj = JSON.parse(process.env.npm_config_argv);
        args = args.concat(argv_obj.cooked.slice(1));
    }
    var debug = (args.indexOf('--debug') > -1);
    if (debug) { opts.configuration = 'Debug'; }

    opts.stage = (args.indexOf('--stage') > -1);
    if (opts.stage) {
        opts.force = true;
    } else {
        var from_source = args.indexOf('--build-from-source');
        if ( from_source > -1) {
            // no specific module name passed
            next_arg = args[from_source+1];
            if (!next_arg || next_arg.indexOf('--') <= 0) {
                opts.force = true;
            } else if (next_arg === 'sqlite3'){
                opts.force = true;
            }
        }
    }
    var target_arch = args.indexOf('--target_arch');
    if (target_arch > -1) {
        next_arg = args[target_arch+1];
        if (next_arg && next_arg.indexOf('--') < 0) {
            opts.target_arch = next_arg;
        }
    }
    opts.args = args;
    return opts;
}

module.exports.parse_args = parse_args;
module.exports.download = download;
