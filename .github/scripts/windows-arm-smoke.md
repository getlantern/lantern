Run **App Smoke Tests** with `platforms=windows-arm` and `tests=vpn-smoke` for a targeted run. The nightly sweep also includes this job.

The x64 builder produces the normal installer and a Profile build of the existing Windows Flutter connect test. On `windows-11-arm`, the test installs Lantern, launches the installed UI, verifies the installed service matches the ARM64 payload, and drives the Connect and Disconnect buttons in the prebuilt test app. It requires fresh DNS resolution, a changed public IP, and restored IP, DNS servers and default gateways after disconnect.

The job removes the hosted image's Visual C++ v14 runtime before installation so setup must install its bundled prerequisite. It checks WebView2 availability and UI startup as well. This runs only on disposable GitHub ARM runners behind the script's explicit guard.

The upgrade fixture uses the production installer with version `0.0.0` and the same compiled binaries as the normal installer. It exercises installation over an older registered version and replacement of the service. Signed update-feed delivery remains covered by the separate auto-update suite. The ARM job also verifies uninstall removes the app, service and registration, and uploads logs and screenshots for diagnosis.
