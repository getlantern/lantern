# angular-ui-ieshiv

## Important!

If not installed properly, angular WILL throw an exception. 

    "No module: ui.directives"

Which means you have not included the angular-ui library in the file, or the shiv is in the wrong place.

WHY? Well, angular is throwing the exception and I can't catch and stop it. If properly setup, you should be good. 
If not, then you should probably fix it or yank it out. Of course, then you won't have the shiv for ie. 

## Description

This is used in order to support IE versions that do not support custom elements. For example: 

     <ng-view></ng-view>
     <ui-currency ng-model="somenum"></ui-currency>

IE 8 and earlier do not allow custom tag elements into the DOM. It just ignores them. 
In order to remedy, the trick is to tell browser by calling document.createElement('my-custom-element').
Then you can use, <my-custom-element>...</my-custom-element>, you also may need to define css styles. 

In current version, this will automagically define directives found in the ui.directives module and 
angular's ngView, ngInclude, ngPluralize directives.

## Usage

The shiv needs to run after angular has compiled the application.  Best to load angular-ui-ieshiv.js at 
bottom of <head> section. 

    <!--[if lte IE 8]> <script src="build/angular-ui-ieshiv.js"></script><![endif]-->

### Options

    There will be

### Notes
    - modules are searched for directives 
    - only IE 8 and earlier will cause shiv to run
    - there will be a slight performance hit (for IE) 
    
### Todo
    - provide ability to specify which directives to include/exclude
    - automagically locate all custom directives in current ng-app (this will involve recursion)
    