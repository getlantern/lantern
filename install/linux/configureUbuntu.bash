#!/usr/bin/env bash


#su $USER -c "mkdir -p ~/.lantern/logs &> /dev/null"

#echo "Copying lantern.desktop so ubuntu can find it"
echo "User is '$USER'"
# DRY warning: see
#  - install/linux/lantern-autostart.desktop
#  - src/main/java/org/lantern/ChromeRunner.java
#  - src/main/java/org/lantern/http/JettyLauncher.java
#
#  StartupWMClass=127.0.0.1 is needed so the lantern icon will show up in the
#  Unity launcher/dock.  But if we specify only that, the lantern icon might
#  appear for any other chrome app served from localhost.  So we rename the
#  index file to something less likely to cause name clashes.
#echo 'StartupWMClass=127.0.0.1__org.lantern.index.html' >> /usr/share/applications/lantern.desktop
cp /opt/lantern/lantern.desktop /usr/share/applications
chown $USER:$USER /opt/lantern/lantern.desktop
chown $USER:$USER /usr/share/applications/lantern.desktop


cp $I4J_INSTALL_LOCATION/java7/* $I4J_INSTALL_LOCATION/jre/lib/security/ || echo "Could not copy policy files!!"

echo "************************************************************************************"
echo "************************************************************************************"
echo ""
echo "            Congratulations, you have successfully installed Lantern.               "
echo " To run it, simply type 'lantern' on the command line or run it from Dash on Ubuntu "
echo ""
echo "************************************************************************************"
echo "************************************************************************************"
#lantern &
#su $USER -c "lantern &"
