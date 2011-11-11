
Processing.js - 1.3.6
=========================
a port of the Processing visualization language

About Us
--------
* License:           MIT (see included LICENSE file for full license)
* Original Author:   John Resig (http://ejohn.org)
* Maintainers:       See included AUTHORS file for contributor list
* Web Site:          http://processingjs.org
* Github Repo:       http://github.com/jeresig/processing-js
* Bug Tracker:       http://processing-js.lighthouseapp.com

Contributing and/or Participating Organizations
-----------------------------------------------
* The Processing Project and Community:  http://processing.org
* The Mozilla Foundation:                https://www.mozilla.org/foundation/
* Seneca College (CDOT):                 http://zenit.senecac.on.ca/wiki/

Contact Us
----------
* IRC Channel: Join the development team at irc://irc.mozilla.org/processing.js
* Mailing List: User discussions happen at http://groups.google.com/group/processingjs
* Twitter: http://twitter.com/processingjs

What is Processing.js?
----------------------
Processing.js is the sister project of the popular visual programming language
Processing, designed for the web. Processing.js makes your data visualizations,
digital art, interactive animations, educational graphs, video games, etc. work
using web standards and without any plug-ins. You write code using the Processing
language (or JavaScript), include it in your web page, and Processing.js does the
rest.

Processing.js is perhaps best thought of as a JavaScript runtime for the Processing
language. Where Processing relies upon Java for its graphics back-end, Processing.js
uses the web--HTML5, canvas, and WebGL--to create 2D and 3D graphics, without
developers having to learn those APIs and technologies.

Originally developed by Ben Fry and Casey Reas, Processing started as an open
source programming language based on Java to help the electronic arts and visual
design communities learn the basics of computer programming in a visual context.
Processing.js takes this to the next level, allowing Processing code to be run by
any HTML5 compatible browser, including current versions of Firefox, Safari,
Chrome, Opera, and Internet Explorer. Processing.js brings the best of visual
programming to the web, both for Processing and web developers.

Much like the native language, Processing.js is a community driven project,
and continues to grow as browser technology advances.  Processing.js is now
compatible with Processing, and has an active developer and user community.

Platform and Browser Compatibility
----------------------------------
Processing.js is explicitly developed for and actively tested on browsers that
support the HTML5 canvas element. Processing.js runs in FireFox, Safari,
Chrome, Opera, and Internet Explorer.

Processing.js aims for 100 percent compatibility across all supported browsers;
however, differences between individual canvas implementations may give
slightly different results in your sketches.

Setting up a Simple Sketch
--------------------------
In order to get a sketch going in the browser you will need to download the
processing.js file and make two new files - one with the extension .html and
the other with the extension .pde.

The .html file will have a link to the processing.js file you have downloaded,
and a canvas tag with a link to the .pde file that you made.

Here is an example of an .html file:

    <!doctype html>
    <html>
      <head>
        <script src="processing.js"></script>
      </head>
      <body>
        <canvas data-processing-sources="mySketch.pde"></canvas>
      </body>
    </html>

The custom attribute _data-processing-sources_ is used to link the sketch to
the canvas.

Here is an example of a Processing sketch:

    void setup() {
      size(200, 200);
      background(125);
      fill(255);
      noLoop();
      PFont fontA = loadFont("courier");
      textFont(fontA, 14);
    }

    void draw() {
      text("Hello Web!", 20, 20);
      println("Hello Error Log!");
    }

Many more examples are available on the Processing.js website, http://processingjs.org/.

Loading Processing.js Sketches Locally
--------------------------------------
Some web browsers (e.g., Chrome) require secondary files to be loaded from a
web server for security reasons.  This means loading a web page that references
a Processing.js sketch in a file via a file:/// URL vs. http:// will fail. You
are particularly likely to run into this problem when you try to view your
webpage directly from file, as this makes all relatively links file:/// links.

There are several ways to get around this problem. You can use a browser which
does allow file:/// access, although most current browsers either have, or plan
to, no longer allow this by default. Another option is to run your own localhost
webserver so that you can test your page from http://localhost, thus avoiding
file:/// URLs. If you do not have a webserver installed, you can use the simple
webserver that is bundled with Processing.js. This requires Python to be installed,
and can be started by running the "httpd.py" script. This will set up a localhost
webserver instance for as long as you keep it running, so that you can easily
test your page in any browser of your choosing.

Finally, most browsers can be told to turn off their same-origin policy
restrictions, allowing you to test your page without running a localhost
webserver.  However, we strongly advise against this as it will disable
same-origin policy checking for any and all websites that you visit until
you turn it back on. While "easy", this is unsafe.

Learn More About Processing.js
-------------------------------
Processing developers should start with the Processing.js Quick Start Guide for
Processing Developers at http://processingjs.org/reference/articles/p5QuickStart.

JavaScript developers should start with the Processing.js Quick Start Guide for
JavaScript Developers at http://processingjs.org/reference/articles/jsQuickStart

A more detailed guide is http://processingjs.org/reference/articles/PomaxGuide.

A complete reference of all Processing.js functions and variables is available
at http://processingjs.org/reference.
