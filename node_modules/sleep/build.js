
if (process.platform !== 'win32') {
  require('child_process').exec('node-waf clean || true; node-waf configure build', function(err, stdout, stderr) {
    console.log(stdout);
    console.log(stderr);
  });
}

