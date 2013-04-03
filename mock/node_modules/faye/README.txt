= Faye

* http://faye.jcoglan.com
* http://groups.google.com/group/faye-users
* http://github.com/faye/faye

Faye is a set of tools for dirt-simple publish-subscribe messaging between web
clients. It ships with easy-to-use message routing servers for Node.js and Rack
applications, and clients that can be used on the server and in the browser.

See http://faye.jcoglan.com for documentation.


== Questions, issues, ideas

Please raise questions on the mailing list: http://groups.google.com/group/faye-users,
and feel free to announce and share ideas on Faye-related projects here too. I'd
appreciate it if we only use the GitHub issue tracker for bona fide bugs; You'll
probably get better and quicker answers to questions from the mailing list.


== Development

To hack on Faye, you'll need Ruby in order to build both the Gem and the NPM
package. There are also a few submodules we use for testing. The following
should get you up and running:

  # Download the code from Git
  git clone git://github.com/faye/faye.git
  cd faye
  git submodule update --init --recursive
  
  # Install dependencies
  bundle install
  npm install
  
  # Build Faye
  bundle exec jake
  
  # Run tests
  bundle exec rspec -c spec/
  node spec/node.js
  
  # Install Ruby gem
  gem build faye.gemspec
  gem install faye-x.x.x.gem
  
  # Install NPM package
  npm install build


== To-do

* Provide reflection API for internal stats on channels, subscriptions, message queues
* (Maybe) build a monitoring GUI into the server
* Add sugar for authentication extensions for protected subscribe + publish
* Provide support for user-defined <tt>/service/*</tt> channels
* Let local server-side clients listen to <tt>/meta/*</tt> channels


== License

(The MIT License)

Copyright (c) 2009-2013 James Coglan and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the 'Software'), to deal in
the Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

