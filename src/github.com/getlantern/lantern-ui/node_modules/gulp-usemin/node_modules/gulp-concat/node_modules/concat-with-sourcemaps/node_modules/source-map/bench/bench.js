// Ensure that benchmarks don't get optimized away by calling this blackbox
// function in your benchmark's action.
window.__benchmarkResults = [];
window.benchmarkBlackbox = [].push.bind(window.__benchmarkResults);

// Benchmark running an action n times.
function benchmark(name, setup, action) {
  window.__benchmarkResults = [];
  setup();

  // Warm up the JIT.
  var start = Date.now();
  while ((Date.now() - start) < 10000 /* 10 seconds */) {
    action();
  }

  var stats = new Stats("ms");

  console.profile(name);
  var start = Date.now();
  while ((Date.now() - start) < 20000 /* 20 seconds */) {
    var thisIterationStart = window.performance.now();
    action();
    stats.take(window.performance.now() - thisIterationStart);
  }
  console.profileEnd(name);

  return stats;
}

// Run a benchmark when the given button is clicked and display results in the
// given element.
function benchOnClick(button, results, name, setup, action) {
  button.addEventListener("click", function (e) {
    e.preventDefault();
    var stats = benchmark(name, setup, action);
    results.innerHTML = `
      <table>
        <thead>
          <tr>
            <td>Samples</td>
            <td>Total (${stats.unit})</th>
            <td>Mean (${stats.unit})</th>
            <td>Standard Deviation (%)</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>${stats.samples()}</td>
            <td>${stats.total().toFixed(3)}</td>
            <td>${stats.mean().toFixed(3)}</td>
            <td>${stats.stddev().toFixed(2)}</td>
          </tr>
        </tbody>
      </table>
    `;
  }, false);
}

var EXPECTED_NUMBER_OF_MAPPINGS = 2350714;

benchOnClick(document.getElementById("bench-consumer"),
             document.getElementById("consumer-results"),
             "parse source map",
             function () {},
             function () {
               var smc = new sourceMap.SourceMapConsumer(window.testSourceMap);
               if (smc._generatedMappings.length !== EXPECTED_NUMBER_OF_MAPPINGS) {
                 throw new Error("Expected " + EXPECTED_NUMBER_OF_MAPPINGS + " mappings, found "
                                 + smc._generatedMappings.length);
               }
               benchmarkBlackbox(smc._generatedMappings.length);
             });

benchOnClick(document.getElementById("bench-generator"),
             document.getElementById("generator-results"),
             "serialize source map",
             function () {
               if (!window.smg) {
                 var smc = new sourceMap.SourceMapConsumer(window.testSourceMap);
                 window.smg = sourceMap.SourceMapGenerator.fromSourceMap(smc);
               }
             },
             function () {
               benchmarkBlackbox(window.smg.toString());
             });
