' ============================================================================
' CustomizeInstall.vbs
'
' Silently installs the M-Files desktop client and pre-configures the default
' vault connection, so end users don't have to manually add the vault on
' first login. Writes a registry marker for RMM/Intune detection logic.
'
' Usage:
'   cscript.exe //nologo CustomizeInstall.vbs "<MsiPath>" "<VaultServer>" "<VaultGuid>"
'
' Example:
'   cscript.exe //nologo CustomizeInstall.vbs "\\server\share\MFilesClient.msi" ^
'       "vault.clientorg-a.blackmambacyber.com" "{VAULT-GUID-PLACEHOLDER}"
'
' NOTE: Reconstructed for portfolio purposes — sanitized of real client/tenant
' data. Contact: hebert@blackmambacyber.com
' ============================================================================

Option Explicit

Dim objShell, objFSO, objRegistry
Dim strMsiPath, strVaultServer, strVaultGuid
Dim strLogPath, strDetectionKey
Dim intExitCode

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

strDetectionKey = "HKLM\SOFTWARE\BlackMambaCyber\MFilesDeploy\"

' --- Argument validation ---------------------------------------------------
If WScript.Arguments.Count < 3 Then
    WScript.Echo "Usage: CustomizeInstall.vbs <MsiPath> <VaultServer> <VaultGuid>"
    WScript.Quit 87 ' ERROR_INVALID_PARAMETER
End If

strMsiPath = WScript.Arguments(0)
strVaultServer = WScript.Arguments(1)
strVaultGuid = WScript.Arguments(2)
strLogPath = objShell.ExpandEnvironmentStrings("%TEMP%") & "\MFilesInstall.log"

If Not objFSO.FileExists(strMsiPath) Then
    WScript.Echo "MSI not found at: " & strMsiPath
    WScript.Quit 1603
End If

' --- Silent install ----------------------------------------------------
' /qn        = fully silent, no UI
' /norestart = suppress automatic reboot
' VAULTSERVER / VAULTGUID are custom MSI properties consumed by a Registry
' table entry in the M-Files MSI package to pre-seed the vault connection
' (configured via an MSI transform when the package was built).
Dim strInstallCmd
strInstallCmd = "msiexec.exe /i """ & strMsiPath & """ /qn /norestart " & _
                "VAULTSERVER=""" & strVaultServer & """ " & _
                "VAULTGUID=""" & strVaultGuid & """ " & _
                "/log """ & strLogPath & """"

intExitCode = objShell.Run(strInstallCmd, 0, True)

' MSI success codes: 0 = success, 3010 = success, reboot required
If intExitCode = 0 Or intExitCode = 3010 Then
    ' --- Write detection marker for RMM / Intune ---------------------------
    On Error Resume Next
    objShell.RegWrite strDetectionKey & "Installed", "1", "REG_SZ"
    objShell.RegWrite strDetectionKey & "VaultServer", strVaultServer, "REG_SZ"
    objShell.RegWrite strDetectionKey & "InstalledDate", Now(), "REG_SZ"
    On Error Goto 0

    WScript.Echo "M-Files client installed successfully (exit code " & intExitCode & "). Log: " & strLogPath
    WScript.Quit intExitCode
Else
    WScript.Echo "M-Files install FAILED with exit code " & intExitCode & ". See log: " & strLogPath
    WScript.Quit intExitCode
End If
