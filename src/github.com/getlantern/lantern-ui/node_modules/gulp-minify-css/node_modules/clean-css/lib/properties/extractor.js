// This extractor is used in advanced optimizations
// IMPORTANT: Mind Token class and this code is not related!
// Properties will be tokenized in one step, see #429

function extract(token) {
  var properties = [];

  if (token.kind == 'selector') {
    var inSimpleSelector = !/[\.\+#>~\s]/.test(token.metadata.selector);
    for (var i = 0, l = token.metadata.bodiesList.length; i < l; i++) {
      var property = token.metadata.bodiesList[i];
      if (property.indexOf('__ESCAPED') === 0)
        continue;

      var splitAt = property.indexOf(':');
      var name = property.substring(0, splitAt);
      if (!name)
        continue;

      var nameRoot = findNameRoot(name);

      properties.push([
        name,
        property.substring(splitAt + 1),
        nameRoot,
        property,
        token.metadata.selectorsList,
        inSimpleSelector
      ]);
    }
  } else if (token.kind == 'block') {
    for (var j = 0, k = token.body.length; j < k; j++) {
      properties = properties.concat(extract(token.body[j]));
    }
  }

  return properties;
}

function findNameRoot(name) {
  if (name == 'list-style')
    return name;
  if (name.indexOf('-radius') > 0)
    return 'border-radius';
  if (name.indexOf('border-') === 0)
    return name.match(/border\-\w+/)[0];
  if (name.indexOf('text-') === 0)
    return name;

  return name.replace(/^\-\w+\-/, '').match(/([a-z]+)/)[0];
}

module.exports = extract;
