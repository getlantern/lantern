var PropertyOptimizer = require('../../properties/optimizer');
var CleanUp = require('./clean-up');

var extractProperties = require('../../properties/extractor');
var canReorder = require('../../properties/reorderable').canReorder;
var canReorderSingle = require('../../properties/reorderable').canReorderSingle;

function AdvancedOptimizer(options, context) {
  this.options = options;
  this.minificationsMade = [];
  this.propertyOptimizer = new PropertyOptimizer(this.options, context);
}

function changeBodyOf(token, newBody) {
  token.body = newBody.tokenized;
  token.metadata.body = newBody.list.join(';');
  token.metadata.bodiesList = newBody.list;
}

function changeSelectorOf(token, newSelectors) {
  token.value = newSelectors.tokenized;
  token.metadata.selector = newSelectors.list.join(',');
  token.metadata.selectorsList = newSelectors.list;
}

function unsafeSelector(value) {
  return /\.|\*| :/.test(value);
}

function naturalSorter(a, b) {
  return a > b;
}

AdvancedOptimizer.prototype.isSpecial = function (selector) {
  return this.options.compatibility.selectors.special.test(selector);
};

AdvancedOptimizer.prototype.removeDuplicates = function (tokens) {
  var matched = {};
  var forRemoval = [];

  for (var i = 0, l = tokens.length; i < l; i++) {
    var token = tokens[i];
    if (token.kind != 'selector')
      continue;

    var id = token.metadata.body + '@' + token.metadata.selector;
    var alreadyMatched = matched[id];

    if (alreadyMatched) {
      forRemoval.push(alreadyMatched[0]);
      alreadyMatched.unshift(i);
    } else {
      matched[id] = [i];
    }
  }

  forRemoval = forRemoval.sort(function(a, b) {
    return a > b ? 1 : -1;
  });

  for (var j = 0, n = forRemoval.length; j < n; j++) {
    tokens.splice(forRemoval[j] - j, 1);
  }

  this.minificationsMade.unshift(forRemoval.length > 0);
};

AdvancedOptimizer.prototype.mergeAdjacent = function (tokens) {
  var forRemoval = [];
  var lastToken = { selector: null, body: null };
  var adjacentSpace = this.options.compatibility.selectors.adjacentSpace;

  for (var i = 0, l = tokens.length; i < l; i++) {
    var token = tokens[i];

    if (token.kind != 'selector') {
      lastToken = { selector: null, body: null };
      continue;
    }

    if (lastToken.kind == 'selector' && token.metadata.selector == lastToken.metadata.selector) {
      var joinAt = [lastToken.body.length];
      changeBodyOf(
        lastToken,
        this.propertyOptimizer.process(token.value, lastToken.body.concat(token.body), joinAt, true)
      );
      forRemoval.push(i);
    } else if (lastToken.body && token.metadata.body == lastToken.metadata.body &&
        !this.isSpecial(token.metadata.selector) && !this.isSpecial(lastToken.metadata.selector)) {
      changeSelectorOf(
        lastToken,
        CleanUp.selectors(lastToken.value.concat(token.value), false, adjacentSpace)
      );
      forRemoval.push(i);
    } else {
      lastToken = token;
    }
  }

  for (var j = 0, m = forRemoval.length; j < m; j++) {
    tokens.splice(forRemoval[j] - j, 1);
  }

  this.minificationsMade.unshift(forRemoval.length > 0);
};

AdvancedOptimizer.prototype.reduceNonAdjacent = function (tokens) {
  var candidates = {};
  var repeated = [];

  for (var i = tokens.length - 1; i >= 0; i--) {
    var token = tokens[i];

    if (token.kind != 'selector')
      continue;

    var isComplexAndNotSpecial = token.value.length > 1 && !this.isSpecial(token.metadata.selector);
    var selectors = isComplexAndNotSpecial ?
      [token.metadata.selector].concat(token.metadata.selectorsList) :
      [token.metadata.selector];

    for (var j = 0, m = selectors.length; j < m; j++) {
      var selector = selectors[j];

      if (!candidates[selector])
        candidates[selector] = [];
      else
        repeated.push(selector);

      candidates[selector].push({
        where: i,
        list: token.metadata.selectorsList,
        isPartial: isComplexAndNotSpecial && j > 0,
        isComplex: isComplexAndNotSpecial && j === 0
      });
    }
  }

  var reducedInSimple = this.reduceSimpleNonAdjacentCases(tokens, repeated, candidates);
  var reducedInComplex = this.reduceComplexNonAdjacentCases(tokens, candidates);

  this.minificationsMade.unshift(reducedInSimple || reducedInComplex);
};

AdvancedOptimizer.prototype.reduceSimpleNonAdjacentCases = function (tokens, repeated, candidates) {
  var reduced = false;

  function filterOut(idx, bodies) {
    return data[idx].isPartial && bodies.length === 0;
  }

  function reduceBody(token, newBody, processedCount, tokenIdx) {
    if (!data[processedCount - tokenIdx - 1].isPartial) {
      changeBodyOf(token, newBody);
      reduced = true;
    }
  }

  for (var i = 0, l = repeated.length; i < l; i++) {
    var selector = repeated[i];
    var data = candidates[selector];

    this.reduceSelector(tokens, selector, data, {
      filterOut: filterOut,
      callback: reduceBody
    });
  }

  return reduced;
};

AdvancedOptimizer.prototype.reduceComplexNonAdjacentCases = function (tokens, candidates) {
  var reduced = false;
  var localContext = {};

  function filterOut(idx) {
    return localContext.data[idx].where < localContext.intoPosition;
  }

  function collectReducedBodies(token, newBody, processedCount, tokenIdx) {
    if (tokenIdx === 0)
      localContext.reducedBodies.push(newBody);
  }

  allSelectors:
  for (var complexSelector in candidates) {
    var into = candidates[complexSelector];
    if (!into[0].isComplex)
      continue;

    var intoPosition = into[into.length - 1].where;
    var intoToken = tokens[intoPosition];
    var reducedBodies = [];

    var selectors = this.isSpecial(complexSelector) ?
      [complexSelector] :
      into[0].list;

    localContext.intoPosition = intoPosition;
    localContext.reducedBodies = reducedBodies;

    for (var j = 0, m = selectors.length; j < m; j++) {
      var selector = selectors[j];
      var data = candidates[selector];

      if (data.length < 2)
        continue allSelectors;

      localContext.data = data;

      this.reduceSelector(tokens, selector, data, {
        filterOut: filterOut,
        callback: collectReducedBodies
      });

      if (reducedBodies[reducedBodies.length - 1].list.join(';') != reducedBodies[0].list.join(';'))
        continue allSelectors;
    }

    intoToken.body = reducedBodies[0].tokenized;
    reduced = true;
  }

  return reduced;
};

AdvancedOptimizer.prototype.reduceSelector = function (tokens, selector, data, options) {
  var bodies = [];
  var bodiesAsList = [];
  var joinsAt = [];
  var processedTokens = [];

  for (var j = data.length - 1, m = 0; j >= 0; j--) {
    if (options.filterOut(j, bodies))
      continue;

    var where = data[j].where;
    var token = tokens[where];

    bodies = bodies.concat(token.body);
    bodiesAsList.push(token.metadata.bodiesList);
    processedTokens.push(where);
  }

  for (j = 0, m = bodiesAsList.length; j < m; j++) {
    if (bodiesAsList[j].length > 0)
      joinsAt.push((joinsAt[j - 1] || 0) + bodiesAsList[j].length);
  }

  var optimizedBody = this.propertyOptimizer.process(selector, bodies, joinsAt, false);

  var processedCount = processedTokens.length;
  var propertyIdx = optimizedBody.tokenized.length - 1;
  var tokenIdx = processedCount - 1;

  while (tokenIdx >= 0) {
     if ((tokenIdx === 0 || (optimizedBody.tokenized[propertyIdx] && bodiesAsList[tokenIdx].indexOf(optimizedBody.tokenized[propertyIdx].value) > -1)) && propertyIdx > -1) {
      propertyIdx--;
      continue;
    }

    var newBody = {
      list: optimizedBody.list.splice(propertyIdx + 1),
      tokenized: optimizedBody.tokenized.splice(propertyIdx + 1)
    };
    options.callback(tokens[processedTokens[tokenIdx]], newBody, processedCount, tokenIdx);

    tokenIdx--;
  }
};

AdvancedOptimizer.prototype.mergeNonAdjacentBySelector = function (tokens) {
  var allSelectors = {};
  var repeatedSelectors = [];
  var i;

  for (i = tokens.length - 1; i >= 0; i--) {
    if (tokens[i].kind != 'selector')
      continue;
    if (tokens[i].body.length === 0)
      continue;

    var selector = tokens[i].metadata.selector;
    allSelectors[selector] = [i].concat(allSelectors[selector] || []);

    if (allSelectors[selector].length == 2)
      repeatedSelectors.push(selector);
  }

  for (i = repeatedSelectors.length - 1; i >= 0; i--) {
    var positions = allSelectors[repeatedSelectors[i]];

    selectorIterator:
    for (var j = positions.length - 1; j > 0; j--) {
      var positionOne = positions[j - 1];
      var tokenOne = tokens[positionOne];
      var positionTwo = positions[j];
      var tokenTwo = tokens[positionTwo];

      directionIterator:
      for (var direction = 1; direction >= -1; direction -= 2) {
        var topToBottom = direction == 1;
        var from = topToBottom ? positionOne + 1 : positionTwo - 1;
        var to = topToBottom ? positionTwo : positionOne;
        var delta = topToBottom ? 1 : -1;
        var moved = topToBottom ? tokenOne : tokenTwo;
        var target = topToBottom ? tokenTwo : tokenOne;
        var movedProperties = extractProperties(moved);

        while (from != to) {
          var traversedProperties = extractProperties(tokens[from]);
          from += delta;

          // traversed then moved as we move selectors towards the start
          var reorderable = topToBottom ?
            canReorder(movedProperties, traversedProperties) :
            canReorder(traversedProperties, movedProperties);

          if (!reorderable && !topToBottom)
            continue selectorIterator;
          if (!reorderable && topToBottom)
            continue directionIterator;
        }

        var joinAt = topToBottom ? [target.body.length] : [moved.body.length];
        var joinedBodies = topToBottom ? moved.body.concat(target.body) : target.body.concat(moved.body);
        var newBody = this.propertyOptimizer.process(target.value, joinedBodies, joinAt, true);
        changeBodyOf(target, newBody);
        changeBodyOf(moved, { tokenized: [], list: [] });
      }
    }
  }
};

AdvancedOptimizer.prototype.mergeNonAdjacentByBody = function (tokens) {
  var candidates = {};
  var adjacentSpace = this.options.compatibility.selectors.adjacentSpace;

  for (var i = tokens.length - 1; i >= 0; i--) {
    var token = tokens[i];
    if (token.kind != 'selector')
      continue;

    if (token.body.length > 0 && unsafeSelector(token.metadata.selector))
      candidates = {};

    var oldToken = candidates[token.metadata.body];
    if (oldToken && !this.isSpecial(token.metadata.selector) && !this.isSpecial(oldToken.metadata.selector)) {
      changeSelectorOf(
        token,
        CleanUp.selectors(oldToken.value.concat(token.value), false, adjacentSpace)
      );

      changeBodyOf(oldToken, { tokenized: [], list: [] });
      candidates[token.metadata.body] = null;
    }

    candidates[token.metadata.body] = token;
  }
};

AdvancedOptimizer.prototype.restructure = function (tokens) {
  var movableTokens = {};
  var movedProperties = [];
  var multiPropertyMoveCache = {};
  var movedToBeDropped = [];
  var self = this;
  var maxCombinationsLevel = 2;
  var ID_JOIN_CHARACTER = '%';

  function sendToMultiPropertyMoveCache(position, movedProperty, allFits) {
    for (var i = allFits.length - 1; i >= 0; i--) {
      var fit = allFits[i][0];
      var id = addToCache(movedProperty, fit);

      if (multiPropertyMoveCache[id].length > 1 && processMultiPropertyMove(position, multiPropertyMoveCache[id])) {
        removeAllMatchingFromCache(id);
        break;
      }
    }
  }

  function addToCache(movedProperty, fit) {
    var id = cacheId(fit);
    multiPropertyMoveCache[id] = multiPropertyMoveCache[id] || [];
    multiPropertyMoveCache[id].push([movedProperty, fit]);
    return id;
  }

  function removeAllMatchingFromCache(matchId) {
    var matchSelectors = matchId.split(ID_JOIN_CHARACTER);
    var forRemoval = [];
    var i;

    for (var id in multiPropertyMoveCache) {
      var selectors = id.split(ID_JOIN_CHARACTER);
      for (i = selectors.length - 1; i >= 0; i--) {
        if (matchSelectors.indexOf(selectors[i]) > -1) {
          forRemoval.push(id);
          break;
        }
      }
    }

    for (i = forRemoval.length - 1; i >= 0; i--) {
      delete multiPropertyMoveCache[forRemoval[i]];
    }
  }

  function cacheId(cachedTokens) {
    var id = [];
    for (var i = 0, l = cachedTokens.length; i < l; i++) {
      id.push(cachedTokens[i].metadata.selector);
    }
    return id.join(ID_JOIN_CHARACTER);
  }

  function tokensToMerge(sourceTokens) {
    var uniqueTokensWithBody = [];
    var mergeableTokens = [];

    for (var i = sourceTokens.length - 1; i >= 0; i--) {
      if (self.isSpecial(sourceTokens[i].metadata.selector))
        continue;

      mergeableTokens.unshift(sourceTokens[i]);
      if (sourceTokens[i].body.length > 0 && uniqueTokensWithBody.indexOf(sourceTokens[i]) == -1)
        uniqueTokensWithBody.push(sourceTokens[i]);
    }

    return uniqueTokensWithBody.length > 1 ?
      mergeableTokens :
      [];
  }

  function shortenIfPossible(position, movedProperty) {
    var name = movedProperty[0];
    var value = movedProperty[1];
    var key = movedProperty[3];
    var valueSize = name.length + value.length + 1;
    var allSelectors = [];
    var qualifiedTokens = [];

    var mergeableTokens = tokensToMerge(movableTokens[key]);
    if (mergeableTokens.length < 2)
      return;

    var allFits = findAllFits(mergeableTokens, valueSize, 1);
    var bestFit = allFits[0];
    if (bestFit[1] > 0)
      return sendToMultiPropertyMoveCache(position, movedProperty, allFits);

    for (var i = bestFit[0].length - 1; i >=0; i--) {
      allSelectors = bestFit[0][i].value.concat(allSelectors);
      qualifiedTokens.unshift(bestFit[0][i]);
    }

    allSelectors = CleanUp.selectorDuplicates(allSelectors);
    dropAsNewTokenAt(position, [movedProperty], allSelectors, qualifiedTokens);
  }

  function fitSorter(fit1, fit2) {
    return fit1[1] > fit2[1];
  }

  function findAllFits(mergeableTokens, propertySize, propertiesCount) {
    var combinations = allCombinations(mergeableTokens, propertySize, propertiesCount, maxCombinationsLevel - 1);
    return combinations.sort(fitSorter);
  }

  function allCombinations(tokensVariant, propertySize, propertiesCount, level) {
    var differenceVariants = [[tokensVariant, sizeDifference(tokensVariant, propertySize, propertiesCount)]];
    if (tokensVariant.length > 2 && level > 0) {
      for (var i = tokensVariant.length - 1; i >= 0; i--) {
        var subVariant = Array.prototype.slice.call(tokensVariant, 0);
        subVariant.splice(i, 1);
        differenceVariants = differenceVariants.concat(allCombinations(subVariant, propertySize, propertiesCount, level - 1));
      }
    }

    return differenceVariants;
  }

  function sizeDifference(tokensVariant, propertySize, propertiesCount) {
    var allSelectorsSize = 0;
    for (var i = tokensVariant.length - 1; i >= 0; i--) {
      allSelectorsSize += tokensVariant[i].body.length > propertiesCount ? tokensVariant[i].metadata.selector.length : -1;
    }
    return allSelectorsSize - (tokensVariant.length - 1) * propertySize + 1;
  }

  function dropAsNewTokenAt(position, properties, allSelectors, mergeableTokens) {
    var bodyMetadata = {};
    var i, j, k, m;

    for (i = mergeableTokens.length - 1; i >= 0; i--) {
      var mergeableToken = mergeableTokens[i];

      for (j = mergeableToken.body.length - 1; j >= 0; j--) {

        for (k = 0, m = properties.length; k < m; k++) {
          var property = properties[k];

          if (mergeableToken.body[j].value === property[3]) {
            bodyMetadata[property[3]] = mergeableToken.body[j].metadata;

            mergeableToken.body.splice(j, 1);
            mergeableToken.metadata.bodiesList.splice(j, 1);
            mergeableToken.metadata.body = mergeableToken.metadata.bodiesList.join(';');
            break;
          }
        }
      }
    }

    var newToken = { kind: 'selector', metadata: {} };
    var allBodies = { tokenized: [], list: [] };

    for (i = properties.length - 1; i >= 0; i--) {
      allBodies.tokenized.push({ value: properties[i][3] });
      allBodies.list.push(properties[i][3]);
    }

    changeSelectorOf(newToken, allSelectors);
    changeBodyOf(newToken, allBodies);

    for (i = properties.length - 1; i >= 0; i--) {
      newToken.body[i].metadata = bodyMetadata[properties[i][3]];
    }

    tokens.splice(position, 0, newToken);
  }

  function dropPropertiesAt(position, movedProperty) {
    var key = movedProperty[3];

    if (movableTokens[key] && movableTokens[key].length > 1)
      shortenIfPossible(position, movedProperty);
  }

  function processMultiPropertyMove(position, propertiesAndMergableTokens) {
    var valueSize = 0;
    var properties = [];
    var property;

    for (var i = propertiesAndMergableTokens.length - 1; i >= 0; i--) {
      property = propertiesAndMergableTokens[i][0];
      var fullValue = property[3];
      valueSize += fullValue.length + (i > 0 ? 1 : 0);

      properties.push(property);
    }

    var mergeableTokens = propertiesAndMergableTokens[0][1];
    var bestFit = findAllFits(mergeableTokens, valueSize, properties.length)[0];
    if (bestFit[1] > 0)
      return false;

    var allSelectors = [];
    var qualifiedTokens = [];
    for (i = bestFit[0].length - 1; i >= 0; i--) {
      allSelectors = bestFit[0][i].value.concat(allSelectors);
      qualifiedTokens.unshift(bestFit[0][i]);
    }

    allSelectors = CleanUp.selectorDuplicates(allSelectors);
    dropAsNewTokenAt(position, properties, allSelectors, qualifiedTokens);

    for (i = properties.length - 1; i >= 0; i--) {
      property = properties[i];
      var index = movedProperties.indexOf(property);

      delete movableTokens[property[3]];

      if (index > -1 && movedToBeDropped.indexOf(index) == -1)
        movedToBeDropped.push(index);
    }

    return true;
  }

  for (var i = tokens.length - 1; i >= 0; i--) {
    var token = tokens[i];
    var isSelector;
    var j, k, m;

    if (token.kind == 'selector') {
      isSelector = true;
    } else if (token.kind == 'block' && !token.isFlatBlock) {
      isSelector = false;
    } else {
      continue;
    }

    // We cache movedProperties.length as it may change in the loop
    var movedCount = movedProperties.length;

    var properties = extractProperties(token);
    movedToBeDropped = [];

    var unmovableInCurrentToken = [];
    for (j = properties.length - 1; j >= 0; j--) {
      for (k = j - 1; k >= 0; k--) {
        if (!canReorderSingle(properties[j], properties[k])) {
          unmovableInCurrentToken.push(j);
          break;
        }
      }
    }

    for (j = 0, m = properties.length; j < m; j++) {
      var property = properties[j];
      var movedSameProperty = false;

      for (k = 0; k < movedCount; k++) {
        var movedProperty = movedProperties[k];

        if (movedToBeDropped.indexOf(k) == -1 && !canReorderSingle(property, movedProperty)) {
          dropPropertiesAt(i + 1, movedProperty);
          movedToBeDropped.push(k);
          delete movableTokens[movedProperty[3]];
        }

        if (!movedSameProperty)
          movedSameProperty = property[0] == movedProperty[0] && property[1] == movedProperty[1];
      }

      if (!isSelector || unmovableInCurrentToken.indexOf(j) > -1)
        continue;

      var key = property[3];
      movableTokens[key] = movableTokens[key] || [];
      movableTokens[key].push(token);

      if (!movedSameProperty)
        movedProperties.push(property);
    }

    movedToBeDropped = movedToBeDropped.sort(naturalSorter);
    for (j = 0, m = movedToBeDropped.length; j < m; j++) {
      movedProperties.splice(movedToBeDropped[j] - j, 1);
    }
  }

  var position = tokens[0] && tokens[0].kind == 'at-rule' && tokens[0].value.indexOf('@charset') === 0 ? 1 : 0;
  for (; position < tokens.length - 1; position++) {
    var isImportRule = tokens[position].kind === 'at-rule' && tokens[position].value.indexOf('@import') === 0;
    var isEscapedCommentSpecial = tokens[position].kind === 'text' && tokens[position].value.indexOf('__ESCAPED_COMMENT_SPECIAL') === 0;
    if (!(isImportRule || isEscapedCommentSpecial))
      break;
  }

  for (i = 0; i < movedProperties.length; i++) {
    dropPropertiesAt(position, movedProperties[i]);
  }
};

AdvancedOptimizer.prototype.mergeMediaQueries = function (tokens) {
  var candidates = {};
  var reduced = [];

  for (var i = tokens.length - 1; i >= 0; i--) {
    var token = tokens[i];
    if (token.kind != 'block' || token.isFlatBlock === true)
      continue;

    var candidate = candidates[token.value];
    if (!candidate) {
      candidate = [];
      candidates[token.value] = candidate;
    }

    candidate.push(i);
  }

  for (var name in candidates) {
    var positions = candidates[name];

    positionLoop:
    for (var j = positions.length - 1; j > 0; j--) {
      var source = tokens[positions[j]];
      var target = tokens[positions[j - 1]];
      var movedProperties = extractProperties(source);

      for (var k = positions[j] + 1; k < positions[j - 1]; k++) {
        var traversedProperties = extractProperties(tokens[k]);

        // moved then traversed as we move @media towards the end
        if (!canReorder(movedProperties, traversedProperties))
          continue positionLoop;
      }

      target.body = source.body.concat(target.body);
      source.body = [];

      reduced.push(target);
    }
  }

  return reduced;
};

function optimizeProperties(tokens, propertyOptimizer) {
  for (var i = 0, l = tokens.length; i < l; i++) {
    var token = tokens[i];

    if (token.kind == 'selector') {
      changeBodyOf(
        token,
        propertyOptimizer.process(token.value, token.body, false, true)
      );
    } else if (token.kind == 'block') {
      optimizeProperties(token.body, propertyOptimizer);
    }
  }
}

AdvancedOptimizer.prototype.optimize = function (tokens) {
  var self = this;

  function _optimize(tokens, withRestructuring) {
    tokens.forEach(function (token) {
      if (token.kind == 'block') {
        var isKeyframes = /@(-moz-|-o-|-webkit-)?keyframes/.test(token.value);
        _optimize(token.body, !isKeyframes);
      }
    });

    optimizeProperties(tokens, self.propertyOptimizer);

    self.removeDuplicates(tokens);
    self.mergeAdjacent(tokens);
    self.reduceNonAdjacent(tokens);

    self.mergeNonAdjacentBySelector(tokens);
    self.mergeNonAdjacentByBody(tokens);

    if (self.options.restructuring && withRestructuring) {
      self.restructure(tokens);
      self.mergeAdjacent(tokens);
    }

    if (self.options.mediaMerging) {
      var reduced = self.mergeMediaQueries(tokens);
      for (var i = reduced.length - 1; i >= 0; i--) {
        _optimize(reduced[i].body);
      }
    }
  }

  _optimize(tokens, true);
};

module.exports = AdvancedOptimizer;
