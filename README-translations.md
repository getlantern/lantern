#Translations

All Lantern translations are done in the [Lantern project in Transifex](https://www.transifex.com/otf/lantern/):


##Updating translations

To update translations from Transifex, you need the [Transifex command line tool `tx`](http://docs.transifex.com/client/setup/).

In a project that already has its associate Transifex setup configured, such as lantern-ui and lantern-mobile you can simply run:

```
tx pull -a
```

##Pushing new / updated source files to Transifex

```
tx push -s
```

Check for typo or ambiguity before pushing anything to avoid creating unnecessary work for translation volunteers.

Login to Transifex site to add instructions on specific string to provide its context to translators.

##Set up a new project.

See the [Transifex tutorial](http://docs.transifex.com/tutorials/client/).
