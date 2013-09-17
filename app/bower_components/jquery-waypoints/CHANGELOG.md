# Changelog

## v2.0.3

- Add "unsticky" function for sticky shortcut. (Issue #130)
- Exit early from Infinite shortcut if no "more" link exists. (Issue #140)
- Delay height evaluation of sticky shortcut wrapper. (Issue #151)
- Fix errors with Infinite shortcut's parsing of HTML with jQuery 1.9+. (Issue #163)


## v2.0.2

- Add AMD support. (Issue #116)
- Work around iOS issue with cancelled `setTimeout` timers by not using scroll throttling on touch devices. (Issue #120)
- If defined, execute `handler` option passed to sticky shortcut at the end of the stuck/unstuck change. (Issue #123)

## v2.0.1

- Lower default throttle values for `scrollThrottle` and `resizeThrottle`.
- Fix Issue #104: Pixel offsets written as strings are interpreted as %s.
- Fix Issue #100: Work around IE not firing scroll event on document shortening by forcing a scroll check on `refresh` calls.

## v2.0.0

- Rewrite Waypoints in CoffeeScript.
- Add Sticky and Infinite shortcut scripts.
- Allow multiple Waypoints on each element. (Issue #40)
- Allow horizontal scrolling Waypoints. (Issue #14)
- API additions: (#69, 83, 88)
    - prev, next, above, below, left, right, extendFn, enable, disable
- API subtractions:
    - remove
- Remove custom 'waypoint.reached' jQuery Event from powering the trigger.
- $.waypoints now returns object with vertical+horizontal properties and HTMLElement arrays instead of jQuery object (to preserve trigger order instead of jQuery's forced source order).
- Add enabled option.

## v1.1.7

- Actually fix the post-load bug in Issue #28 from v1.1.3.

## v1.1.6

- Fix potential memory leak by unbinding events on empty context elements.

## v1.1.5

- Make plugin compatible with Browserify/RequireJS. (Thanks [@cjroebuck](https://github.com/cjroebuck))

## v1.1.4

- Add handler option to give alternate binding method.
  
## v1.1.3

- Fix cases where waypoints are added post-load and should be triggered immediately.
  
## v1.1.2

- Fixed error thrown by waypoints with triggerOnce option that were triggered via resize refresh.

## v1.1.1

- Fixed bug in initialization where all offsets were being calculated as if set to 0 initially, causing unwarranted triggers during the subsequent refresh.
- Added `onlyOnScroll`, an option for individual waypoints that disables triggers due to an offset refresh that crosses the current scroll point. (All credit to [@knuton](https://github.com/knuton) on this one.)

## v1.1

- Moved the continuous option out of global settings and into the options
  object for individual waypoints.
- Added the context option, which allows for using waypoints within any
  scrollable element, not just the window.

## v1.0.2

- Moved scroll and resize handler bindings out of load.  Should play nicer with async loaders like Head JS and LABjs.
- Fixed a 1px off error when using certain % offsets.
- Added unit tests.

## v1.0.1

- Added $.waypoints('viewportHeight').
- Fixed iOS bug (using the new viewportHeight method).
- Added offset function alias: 'bottom-in-view'.

## v1.0

- Initial release.