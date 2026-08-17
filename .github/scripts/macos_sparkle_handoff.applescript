-- The Flutter integration test owns Lantern's UI. This helper only crosses
-- the native Sparkle boundary and confirms a window exists after relaunch.

property installButtonNames : {"Install Update", "Install and Relaunch"}
property pollInterval : 0.5

on findButton(elementRef)
  tell application "System Events"
    try
      if role of elementRef is "AXButton" then
        set buttonName to name of elementRef as text
        if installButtonNames contains buttonName and enabled of elementRef then return elementRef
      end if
    end try
    try
      set children to UI elements of elementRef
    on error
      set children to {}
    end try
  end tell
  repeat with childRef in children
    set matchRef to my findButton(childRef)
    if matchRef is not missing value then return matchRef
  end repeat
  return missing value
end findButton

on processForPID(targetPID)
  tell application "System Events"
    repeat with processRef in application processes
      try
        if (unix id of processRef as integer) is targetPID then return processRef
      end try
    end repeat
  end tell
  return missing value
end processForPID

on findInstallButton(processRef)
  tell application "System Events"
    try
      set processWindows to windows of processRef
    on error
      set processWindows to {}
    end try
  end tell
  repeat with windowRef in processWindows
    set matchRef to my findButton(windowRef)
    if matchRef is not missing value then return matchRef
  end repeat
  return missing value
end findInstallButton

on waitForInstallButton(targetPID, timeoutSeconds)
  set deadline to (current date) + timeoutSeconds
  set checkedAccessibility to false
  repeat while (current date) is less than deadline
    set processRef to my processForPID(targetPID)
    if processRef is not missing value then
      if not checkedAccessibility then
        tell application "System Events"
          try
            count of UI elements of processRef
          on error errorMessage number errorNumber
            error "macOS Accessibility is unavailable (" & errorNumber & "): " & errorMessage
          end try
        end tell
        set checkedAccessibility to true
      end if
      set buttonRef to my findInstallButton(processRef)
      if buttonRef is not missing value then return buttonRef
    end if
    delay pollInterval
  end repeat
  error "Sparkle install prompt did not appear before timeout"
end waitForInstallButton

on waitForMainWindow(targetPID, timeoutSeconds)
  set deadline to (current date) + timeoutSeconds
  repeat while (current date) is less than deadline
    set processRef to my processForPID(targetPID)
    if processRef is not missing value then
      tell application "System Events"
        try
          repeat with windowRef in windows of processRef
            if visible of windowRef and subrole of windowRef is "AXStandardWindow" then
              set frontmost of processRef to true
              return "main window ready"
            end if
          end repeat
        end try
      end tell
    end if
    delay pollInterval
  end repeat
  error "Lantern did not expose a main window before timeout"
end waitForMainWindow

on installUntilExit(targetPID, timeoutSeconds)
  set deadline to (current date) + timeoutSeconds
  set pressed to false
  repeat while (current date) is less than deadline
    set processRef to my processForPID(targetPID)
    if processRef is missing value then return "original process exited"
    if not pressed then
      set buttonRef to my findInstallButton(processRef)
      if buttonRef is not missing value then
        tell application "System Events"
          set buttonName to name of buttonRef as text
          perform action "AXPress" of buttonRef
        end tell
        set pressed to true
        log "[E2E] pressed Sparkle " & buttonName
      end if
    end if
    delay pollInterval
  end repeat
  error "Lantern did not exit after accepting the Sparkle update"
end installUntilExit

on positiveInteger(valueText, fieldName)
  try
    set parsedValue to valueText as integer
  on error
    error fieldName & " must be an integer"
  end try
  if parsedValue < 1 then error fieldName & " must be positive"
  return parsedValue
end positiveInteger

on run argv
  if (count of argv) is not 3 then error "action, PID, and timeout are required"
  set actionName to item 1 of argv
  set targetPID to my positiveInteger(item 2 of argv, "PID")
  set timeoutSeconds to my positiveInteger(item 3 of argv, "timeout")

  if actionName is "wait-prompt" then
    set buttonRef to my waitForInstallButton(targetPID, timeoutSeconds)
    tell application "System Events" to return name of buttonRef as text
  end if
  if actionName is "install-until-exit" then
    return my installUntilExit(targetPID, timeoutSeconds)
  end if
  if actionName is "wait-main" then
    return my waitForMainWindow(targetPID, timeoutSeconds)
  end if
  error "unknown action: " & actionName
end run
