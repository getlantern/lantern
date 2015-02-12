# How to contribute to the Lantern code

Patches from the community are more than welcome to make sure Lantern is
working properly on all supported systems, as well as to add features the core
developers have not yet been able to work on. We want to make it as easy as
possible for others to contribute. Here are a few guidelines we ask
contributors to follow to facilitate the process:

## Getting Started

* Make sure you have a [GitHub account](https://github.com/signup/free)
* Submit a ticket for your issue, assuming one does not already exist.
  * Clearly describe the issue including steps to reproduce when it is a bug.
  * Note the earliest version that you know has the issue.
* Fork the repository on GitHub

## Making Changes

* Create a topic branch from where you want to base your work.
  * This is usually the master branch.
  * To quickly create a topic branch based on master; `git branch
    fix/master/my_contribution master` then checkout the new branch with `git
    checkout fix/master/my_contribution`.  Please avoid working directly on the
    `master` branch.
* Make commits of logical units.
* Adhere to the [AngularJS code
  standards](http://docs.angularjs.org/misc/contribute#applyingcodestandards).
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format.

````
    (#99999) Make the example in CONTRIBUTING imperative and concrete

    Without this patch applied the example commit message in the CONTRIBUTING
    document is not a concrete example.  This is a problem because the
    contributor is left to imagine what the commit message should look like
    based on a description rather than an example.  This patch fixes the
    problem by making the example concrete and imperative.

    The first line is a real life imperative statement with a ticket number
    from our issue tracker.  The body describes the behavior without the patch,
    why this is a problem, and how the patch fixes the problem when applied.
````

* Make sure you have added any necessary tests for your changes. Typically
  only refactoring and documentation changes require no new tests.
* Run _all_ the tests to assure nothing else was accidentally broken.

## Submitting Changes

* Push your changes to a topic branch in your fork of the repository.
* Submit a pull request to the repository in the getlantern organization.

# Additional Resources

* [Lantern Wiki](https://github.com/getlantern/lantern/wiki)
* [General contributing](https://github.com/getlantern/lantern/wiki/Contributing)
* [Issue tracker](https://github.com/getlantern/lantern/issues)
* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)
* [General GitHub documentation](http://help.github.com/)
* [#lantern IRC channel](http://webchat.freenode.net/?channels=lantern)
