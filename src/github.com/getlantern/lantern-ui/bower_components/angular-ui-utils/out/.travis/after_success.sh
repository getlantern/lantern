# Inspired by http://sleepycoders.blogspot.se/2013/03/sharing-travis-ci-generated-files.html

if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then

  echo -e "\n>>> Current Repo:$REPO --- Travis Branch:$TRAVIS_BRANCH\n"


  echo -e ">>> Grunt the doc.\n"
  grunt build-doc
  cp -R out $HOME/out


  echo -e ">>> Clone the gh-pages branch.\n"
  cd $HOME
  git clone --branch=gh-pages $REPO  tmp-gh-pages


  echo -e ">>> Replace files.\n"
  cd tmp-gh-pages
  cp -Rf $HOME/out/* .


  echo -e ">>> Force add and commit.\n"
  git add -f .
  git commit -m "Travis commit : build $TRAVIS_BUILD_NUMBER"


  echo -e ">>> Push result :"
  git push -fq origin gh-pages

  echo -e "All done.\n"
fi