*****************************************************************
***                nsProcess NSIS plugin v1.6                 ***
*****************************************************************

2006 Shengalts Aleksander aka Instructor (Shengalts@mail.ru)

Source function FIND_PROC_BY_NAME based
   upon the Ravi Kochhar (kochhar@physiology.wisc.edu) code
Thanks iceman_k (FindProcDLL plugin) and
   DITMan (KillProcDLL plugin) for direct me
NSIS UNICODE compatible version (1.6) by brainsucker
   (sorry, installer missing, i'm too lazy :)

Features:
- Find a process by name
- Kill all processes with specified name (not only one)
- Close all processes with specified name (first tries to close all process windows,
waits for 3 seconds for process to exit, terminates if still alive)
- The process name is case-insensitive
- Win95/98/ME/NT/2000/XP/Win7 support
- Small plugin size (4 Kb)
- NSIS UNICODE support (just rename nsProcessW.dll into nsProcess.dll)

**** Find process ****
${nsProcess::FindProcess} "[file.exe]" $var

"[file.exe]"  - Process name (e.g. "notepad.exe")

$var     0    Success
         603  Process was not currently running
         604  Unable to identify system type
         605  Unsupported OS
         606  Unable to load NTDLL.DLL
         607  Unable to get procedure address from NTDLL.DLL
         608  NtQuerySystemInformation failed
         609  Unable to load KERNEL32.DLL
         610  Unable to get procedure address from KERNEL32.DLL
         611  CreateToolhelp32Snapshot failed


**** Kill/Close process ****
${nsProcess::KillProcess} "[file.exe]" $var
${nsProcess::CloseProcess} "[file.exe]" $var

"[file.exe]"  - Process name (e.g. "notepad.exe")

$var     0    Success
         601  No permission to terminate process
         602  Not all processes terminated successfully
         603  Process was not currently running
         604  Unable to identify system type
         605  Unsupported OS
         606  Unable to load NTDLL.DLL
         607  Unable to get procedure address from NTDLL.DLL
         608  NtQuerySystemInformation failed
         609  Unable to load KERNEL32.DLL
         610  Unable to get procedure address from KERNEL32.DLL
         611  CreateToolhelp32Snapshot failed

**** Comment from brainsucker ****
I'm actually not using macros in my code, plugin calls are easy:

nsProcess:_CloseProcess "notepad.exe"
Pop $R0

**** Unload plugin ****
${nsProcess::Unload}
