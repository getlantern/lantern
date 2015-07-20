#
# Authentication
#
echo -e ">>> AngularUI (angular-ui@googlegroups.com) authentication!\n"

git remote set-url origin $REPO.git
git config --global user.email "angular-ui@googlegroups.com"
git config --global user.name "AngularUI (via TravisCI)"

echo -n $id_rsa_{1..23} >> ~/.ssh/travis_rsa_64
base64 --decode --ignore-garbage ~/.ssh/travis_rsa_64 > ~/.ssh/travis_rsa
chmod 600 ~/.ssh/travis_rsa
echo -e "Host github.com\n\tUser\tgit\n\tIdentityFile\t~/.ssh/travis_rsa\n\tStrictHostKeyChecking\tno\n\tCheckHostIP\tno\n" >> ~/.ssh/config
