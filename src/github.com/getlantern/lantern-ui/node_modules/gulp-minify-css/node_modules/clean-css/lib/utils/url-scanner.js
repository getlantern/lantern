var URL_PREFIX = 'url(';
var UPPERCASE_URL_PREFIX = 'URL(';
var URL_SUFFIX = ')';

function UrlScanner(data, context) {
  this.data = data;
  this.context = context;
}

UrlScanner.prototype.reduce = function (callback) {
  var nextStart = 0;
  var nextStartUpperCase = 0;
  var nextEnd = 0;
  var cursor = 0;
  var tempData = [];
  var data = this.data;
  var hasUppercaseUrl = data.indexOf(UPPERCASE_URL_PREFIX) > -1;

  for (; nextEnd < data.length;) {
    nextStart = data.indexOf(URL_PREFIX, nextEnd);
    nextStartUpperCase = hasUppercaseUrl ? data.indexOf(UPPERCASE_URL_PREFIX, nextEnd) : -1;
    if (nextStart == -1 && nextStartUpperCase == -1)
      break;

    if (nextStart == -1 && nextStartUpperCase > -1)
      nextStart = nextStartUpperCase;

    if (data[nextStart + URL_PREFIX.length] == '"')
      nextEnd = data.indexOf('"', nextStart + URL_PREFIX.length + 1);
    else if (data[nextStart + URL_PREFIX.length] == '\'')
      nextEnd = data.indexOf('\'', nextStart + URL_PREFIX.length + 1);
    else
      nextEnd = data.indexOf(URL_SUFFIX, nextStart);

    // Following lines are a safety mechanism to ensure
    // incorrectly terminated urls are processed correctly.
    if (nextEnd == -1) {
      nextEnd = data.indexOf('}', nextStart);

      if (nextEnd == -1)
        nextEnd = data.length;
      else
        nextEnd--;

      this.context.warnings.push('Broken URL declaration: \'' + data.substring(nextStart, nextEnd + 1) + '\'.');
    } else {
      if (data[nextEnd] != URL_SUFFIX)
        nextEnd = data.indexOf(URL_SUFFIX, nextEnd);
    }

    tempData.push(data.substring(cursor, nextStart));

    var url = data.substring(nextStart, nextEnd + 1);
    callback(url, tempData);

    cursor = nextEnd + 1;
  }

  return tempData.length > 0 ?
    tempData.join('') + data.substring(cursor, data.length) :
    data;
};

module.exports = UrlScanner;
