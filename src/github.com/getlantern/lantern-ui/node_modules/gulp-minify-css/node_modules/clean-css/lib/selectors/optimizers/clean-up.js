function removeWhitespace(match, value) {
  return '[' + value.replace(/ /g, '') + ']';
}

function selectorSorter(s1, s2) {
  return s1.value > s2.value ? 1 : -1;
}

var CleanUp = {
  selectors: function (selectors, removeUnsupported, adjacentSpace) {
    var plain = [];
    var tokenized = [];

    for (var i = 0, l = selectors.length; i < l; i++) {
      var selector = selectors[i];
      var reduced = selector.value
        .replace(/\s+/g, ' ')
        .replace(/ ?, ?/g, ',')
        .replace(/\s*([>\+\~])\s*/g, '$1')
        .trim();

      if (adjacentSpace && reduced.indexOf('nav') > 0)
        reduced = reduced.replace(/\+nav(\S|$)/, '+ nav$1');

      if (removeUnsupported && (reduced.indexOf('*+html ') != -1 || reduced.indexOf('*:first-child+html ') != -1))
        continue;

      if (reduced.indexOf('*') > -1) {
        reduced = reduced
          .replace(/\*([:#\.\[])/g, '$1')
          .replace(/^(\:first\-child)?\+html/, '*$1+html');
      }

      if (reduced.indexOf('[') > -1)
        reduced = reduced.replace(/\[([^\]]+)\]/g, removeWhitespace);

      if (plain.indexOf(reduced) == -1) {
        plain.push(reduced);
        selector.value = reduced;
        tokenized.push(selector);
      }
    }

    return {
      list: plain.sort(),
      tokenized: tokenized.sort(selectorSorter)
    };
  },

  selectorDuplicates: function (selectors) {
    var plain = [];
    var tokenized = [];

    for (var i = 0, l = selectors.length; i < l; i++) {
      var selector = selectors[i];

      if (plain.indexOf(selector.value) == -1) {
        plain.push(selector.value);
        tokenized.push(selector);
      }
    }

    return {
      list: plain.sort(),
      tokenized: tokenized.sort(selectorSorter)
    };
  },

  block: function (block) {
    return block
      .replace(/\s+/g, ' ')
      .replace(/(,|:|\() /g, '$1')
      .replace(/ ?\) ?/g, ')');
  },

  atRule: function (block) {
    return block
      .replace(/\s+/g, ' ')
      .trim();
  }
};

module.exports = CleanUp;
