# [Cha Cha Cha Changes](http://www.youtube.com/watch?v=pl3vxEudif8&t=0m53s)

## Master

## v0.4.0
* **Validate directive** has been upgraded
  * **API BREAKING CHANGE!** now takes expressions instead of function references
  * You must explicitly specify the $value variable, but you no longer need to create a function
  * **NEW FEATURE** uiValidateWatch allows you to re-fire a validation rule (or all rules) when a related model changes (confirm_password)
* **CodeMirror directive** has been updated
  * Now works with v3.02
  * **NEW FEATURE** uiRefresh lets you specify an expression to watch for changes to refresh codemirror (useful for modals)
* **Mask directive** has many new fixes
* Fixes for **uiDate**
  * **DateFormat directive** can now be declared in **uiConfig**
* **uiJq Passthru directive** has upgrades to support a wider variety of directives
  * Now fires asyncronously post-angular-rendering of the view (**uiDefer** option is now always true)
  * New **uiRefresh** lets you specify an expression to watch to re-fire the plugin (call $(elm).focus() when a modal opens)
* **Select2 directive** now adds support for setting the selected item by specifying a simple ID
  * FINALLY have unit-tests for Select2!
* **IEShiv** has been simplified and stripped of browser-sniffing code (just use conditional comments)
* **Calendar directive** now performs better watching of events data
  * Added optional equalsTracker attr (increment to force update from scope)
* **Sortable directive** now properly supports connectWith option
* New **route directive** that sets a boolean based on a pattern match of the current route (useful for tabs/navigation)
* Refactored **If directive** to be tidier
* **API BREAKING CHANGE!** **Modal directive** has been completely removed (if you still need it, grab the files from v0.3.x)

## v0.3.0
* New **format** filter
* Lots of cleanup! Consistent indentation, linting
* Custom builds via grunt (soon to be leveraged via builder)
* uiDate now watches options
* Rewrote ui-keypress (API is not backwards-compatible)
  * **ui-**keypress has been expanded into **ui-keyup**, **ui-keydown** and **ui-keypress**
  * The **ui-keypress** can now be used to `$event.preventDefault()` as expected
  * Multiple combinations are separated by spaces, while multi-key combos are separated by dashes: `'enter alt-space 13-shift':'whatever()'`
  * The string-notation (__a and be or c and d__) has been dropped completely
* Can now pass (or globally define) the value uiReset resets to

## v0.2.0
* Unit tests. Unit tests. Unit tests.
* New **inflector** filter (previously named **prettifier**)
  * Added 2 alternative modes, now contains: humanize, underscore and variable
* **Passthrough directive** (uiJq) now fixes common ngModel problems due to trigger(change). Can optionally be disabled
* Removed **Length Filter** (you can instead do {{ ( myArray | filter: { gender:'m' } ).length }})
* Added **validate directive**, allows you to pass validation functions
* **Sortable directive**
* Fixed **unique filter**
* **Highlight filter** has had bug fixes
* **Event directive** has been refactored / improved
* **Keypress directive** has been refactored / improved
* New **if-directive** instead of **remove directive** (removed)
* New **google maps directive**
* New **animate directive** that transitions the injection of new DOM elements (transitioning the removal of DOM is still not supported yet)
* Improvements to **scrollfix directive**

## v0.1.0
* New folder structure
* Too many to list
