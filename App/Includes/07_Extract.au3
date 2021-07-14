#include-once

; ---------------------------------------------------------------------------------------------
; Extracts all the downloaded (selected) mods. Certain NSIS-Setups are "automated". Look at _NSIS to see what's done.
; ---------------------------------------------------------------------------------------------
Func Au3Extract($p_Num = 0)
	Local $Message = IniReadSection($g_TRAIni, 'Ex-Au3Extract')
	_PrintDebug('+' & @ScriptLineNumber & ' Calling Au3Extract')
	$g_LogFile = $g_LogDir & '\EE-Debug-Extraction.log'
	$g_CurrentPackages = _GetCurrent(); items may be removed due to EET-install-exception
	_Process_SwitchEdit(0, 1)
	Local $Prefix[4] = [3, '', 'Add', $g_ATrans[$g_ATNum] & '-Add']
	Local $Sizes = _GetArchiveSizes()
	GUICtrlSetData($g_UI_Interact[6][4], _GetSTR($Message, 'H1')); => help-text
	GUICtrlSetData($g_UI_Static[6][1], _GetTR($Message, 'L1')); => watch process
	If $g_BG1Dir <> '-' Then _Extract_MissingBG1()
	If $g_FItem <> '1' Then; skip done components
		For $e = 1 To $g_CurrentPackages[0][0]
			If $g_CurrentPackages[$e][0] <> $g_FItem Then; this is not the first new item
				For $p=1 to 3
					$Sizes[0][2]+=$Sizes[$e][$p]
				Next
				ContinueLoop
			Else; got the item
				$g_FItem = $e
				ExitLoop
			EndIf
		Next
	EndIf
	GUICtrlSetData($g_UI_Interact[6][1], ($Sizes[0][2] * 100) / $Sizes[0][1]); set the current value at the beginning
	For $e = $g_FItem To $g_CurrentPackages[0][0]
		IniWrite($g_BWSIni, 'Options', 'Start', $g_CurrentPackages[$e][0]); create entry to enable resume
		If $g_Flags[0] = 0 Then; the exit button was pressed
			Exit
		EndIf
; ---------------------------------------------------------------------------------------------
; pause due to current decision
; ---------------------------------------------------------------------------------------------
		If $g_Flags[11] = 1 Then _Process_Pause()
		$ReadSection = IniReadSection($g_MODIni, $g_CurrentPackages[$e][0])
		$Mod = _IniRead($ReadSection, 'Name', $g_CurrentPackages[$e][0])
		GUICtrlSetData($g_UI_Static[6][2], _GetTR($Message, 'L2') & ' ' & $Mod); => checking
		_Process_SetConsoleLog(_GetTR($Message, 'L2') & ' ' & $Mod & ' ...'); => checking
		If _IniRead($ReadSection, 'Save', 'Manual') = 'Manual' OR _IniRead($ReadSection, 'Save', 'Manual') = '' Then
			_Process_SetConsoleLog(StringFormat(_GetTR($Message, 'L3'), $Mod)); => included in another mod
			FileWrite($g_LogFile, @CRLF & StringFormat(_GetTR($Message, 'L3'), $Mod) & @CRLF); => included in another mod
			$Success = 1; Set success for potential following lang-archives without main-archives
		Else
			$Success = _Extract_CheckMod(_IniRead($ReadSection, 'Save', ''), $g_DownDir, $Mod)
			$Sizes[0][2]+=$Sizes[$e][1]
			GUICtrlSetData($g_UI_Interact[6][1], ($Sizes[0][2] * 100) / $Sizes[0][1])
			If $Success <> 1 Then IniWrite($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], 1); save the error
; ---------------------------------------------------------------------------------------------
; Check if the tp2-file from the core-mod does exist. If not, try to move the file from within a subdir
; ---------------------------------------------------------------------------------------------
			$TP2Exists = _Test_GetCustomTP2($g_CurrentPackages[$e][0], '\', 1); 1 = don't complain if BACKUP mod folder is not found
			If $TP2Exists = '0' And $Success <> '0' Then; Do some more stuff to get it done
				$DirList = StringSplit(StringStripCR($g_ConsoleOutput), @LF)
				For $n = $DirList[0] To 3 Step -1
					If StringInStr($DirList[$n], 'Everything is Ok') Then
						$Dir = StringRegExpReplace($DirList[$n - 2], '(?i)extracting\s*|\x5c.*', ''); stripped 7z info and everything after a potential backslash
						$IsDir = FileGetAttrib($g_GameDir & '\' & $Dir); get the attrib of this file or directory
						If StringInStr($IsDir, 'D') Then $TP2Exists = _Test_GetCustomTP2($g_CurrentPackages[$e][0], '\'&$Dir&'\', 1); 1 = don't complain if BACKUP mod folder is not found
						ExitLoop
					EndIf
				Next
				If $TP2Exists <> '0' Then; this is a folder
					FileWrite($g_LogFile, '>' & $Dir & '\* .' & @CRLF)
					_Extract_MoveMod($Dir)
				Else; search for archives that are inside the archive
					$FileList = StringSplit(StringStripCR($g_ConsoleOutput), @LF)
					For $n = 14 To 1 Step -1
						If StringRegExp($FileList[$n], '(?i)7z\z|rar\z|zip\z') Then
							If StringInStr($FileList[$n], 'Weidu.exe') Then ContinueLoop; don't extract WeiDU
							FileWrite($g_LogFile, '>' & $FileList[$n] & @CRLF)
							$Success = _Extract_CheckMod(StringRegExpReplace($FileList[$n], '(?i)extracting\s*', ''), $g_GameDir, $Mod)
							If $Success <> 1 Then
								IniWrite($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], 1); save the error
								ExitLoop
							Else
								ExitLoop
							EndIf
						EndIf
					Next
				EndIf
			EndIf
		EndIf
; ---------------------------------------------------------------------------------------------
; Check for the additional archives that need to be extracted
; ---------------------------------------------------------------------------------------------
		$Prefix[3] = _GetTra($ReadSection, 'T')&'-Add'; adjust the language-addon
		For $p = 2 To 3
			$SaveAs = _IniRead($ReadSection, $Prefix[$p]&'Save', '')
			If $SaveAs <> '' Then
				If $Success = 1 Then; all ok
					$AddSuccess=_Extract_CheckMod($SaveAs, $g_DownDir, $Mod & ' - ' & _GetTR($Message, 'L4')); =>additional
					If $AddSuccess <> 1 Then
						IniWrite($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], IniRead($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], '') & $p); save addon-error
						$Success = 0; save the error for the possible lang-addon
					EndIf
				Else
					IniWrite($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], IniRead($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], '') & ($p+2)); not unpacked due to error
				EndIf
				$Sizes[0][2]+=$Sizes[$e][$p]
			EndIf
			GUICtrlSetData($g_UI_Interact[6][1], ($Sizes[0][2] * 100) / $Sizes[0][1])
		Next
	Next
; ---------------------------------------------------------------------------------------------
; If troublesome NSIS-Setups were found, process them now. Those mods do not extract correctly, into wired directories, ...
; ---------------------------------------------------------------------------------------------
	If _Extract_InstallNSIS($g_GameDir) = 1 Then
		GUISetState(@SW_RESTORE, $g_UI[0])
		If FileExists($g_GameDir & '\NSIS') Then
			Local $Fault=IniReadSection($g_BWSIni, 'Faults'); NSIS-packages are handled as errors per default, so faults may be NSIS
			If Not @error Then
				For $f=1 to $Fault[0][0]
					If $Fault[$f][1] <> '1' Then ContinueLoop
					$TP2Exists = _Test_GetCustomTP2($Fault[$f][0], '\NSIS\', 1); 1 = don't complain if BACKUP mod folder is not found
					If $TP2Exists <> '0' Then IniDelete($g_BWSIni, 'Faults', $Fault[$f][0]); if NSIS-package is found, remove error
				Next
			EndIf
			$Success = _Extract_MoveMod('NSIS')
			If $Success = 1 Then
				_Misc_MsgGUI(1, _GetTR($Message, 'T1'), _GetTR($Message, 'L5'), 1, _GetTR($Message, 'B1'), '', '', 5); => continue in 5 seconds
			Else
				ShellExecute($g_GameDir & '\NSIS')
				$Type=StringRegExpReplace($g_Flags[14], '(?i)BWS|BWP', 'BG2')
				$Test=_Misc_MsgGUI(3, _GetTR($g_UI_Message, '0-T1'), StringFormat(_GetTR($Message, 'L7'), $Type), 2, _GetTR($g_UI_Message, '8-B3'), _GetTR($Message, 'B1')); =>could not close nor move NSIS-files.; =>could not close nor move NSIS-files.
				If $Test = 2 Then Exit
			EndIf
		EndIf
	EndIf
	IniWrite($g_BWSIni, 'Order', 'Au3Extract', 0); Skip this one if the Setup is rerun
EndFunc   ;==>Au3Extract

; ---------------------------------------------------------------------------------------------
; Try to extract archives that are missing
; ---------------------------------------------------------------------------------------------
Func Au3ExFix($p_Num)
	Local $Message = IniReadSection($g_TRAIni, 'Ex-Au3Extract')
	_PrintDebug('+' & @ScriptLineNumber & ' Calling Au3ExFix')
	$g_LogFile = $g_LogDir & '\EE-Debug-Extraction.log'
	$g_CurrentPackages = _GetCurrent(); May be needed if BWS is restarted during fixing
	$g_Flags[0] = 1
	_Process_SwitchEdit(0, 0)
	GUICtrlSetData($g_UI_Interact[6][4], _GetSTR($Message, 'H1')); => help text
	GUICtrlSetData($g_UI_Static[6][1], _GetTR($Message, 'L1')); => watch progress
	_Process_SetConsoleLog(_GetTR($Message, 'L6')); => test for more possible extractions
	If $g_BG1Dir <> '-' Then _Extract_MissingBG1()
; ---------------------------------------------------------------------------------------------
; do another run for NSIS
; ---------------------------------------------------------------------------------------------
	If _Extract_InstallNSIS($g_GameDir) = 1 Then
		GUISetState(@SW_RESTORE, $g_UI[0])
		_Misc_MsgGUI(1, _GetTR($Message, 'T1'), _GetTR($Message, 'L5'), 1, _GetTR($Message, 'B1'), '', '', 5); => finished, you can continue
	EndIf
	If FileExists($g_GameDir & '\NSIS') Then _Extract_MoveMod('NSIS')
; ===============  extract the additional files of Infinity Animations  ===============
	$7za = _StringVerifyAscII($g_ProgDir) & '\Tools\7z.exe'
	If StringRegExp($g_Flags[14], 'BWP|BWS') And _IniRead($g_CurrentPackages, 'INFINITYANIMATIONS', '') <> '' Then; IA is only supported for BG2-games and is checked if selected
		$IATest=IniReadSection($g_UsrIni, 'Save')
		$IATest[0][1] = '|'; we'll save the selection here for a stringtest later
		FileDelete($g_BG2Dir & '\infinityanimations\restore\*'); delete old stuff that may be faulty
		FileDelete($g_BG2Dir & '\infinityanimations\content\*')
		For $c=1 to 14
			If StringLen($c) = 1 Then $c='0'&$c
			If _IniRead($IATest, 'IAContent'&$c, '') <> '' Then; Content was selected
				$ReadSection = IniReadSection($g_MODIni, 'IAContent'&$c)
				$Save = _IniRead($ReadSection, 'Save', '')
				If $Save = '' Then ContinueLoop
				If Not FileExists($g_DownDir & '\' & $Save) Then ContinueLoop
				$IATest[0][1]&=StringRight('IAContent'&$c, 2)&'|'; append selected package number
				$Mod = _IniRead($ReadSection, 'Name', 'IAContent'&$c)
				$iSize = Round(_IniRead($ReadSection, 'Size', 0) / (1024 * 1024), 1)
				If $iSize = '0.0' Then $iSize = '0.1'
				GUICtrlSetData($g_UI_Static[6][2], IniRead($g_TRAIni, 'Ex-CheckMod', 'L1', '') & ' ' & $Mod & ' (' & $iSize & ' MB)'); set "extraction"-info
				If StringInStr($Save, 'Restore') Then; get the correct path
					$Path=$g_BG2Dir & '\infinityanimations\restore'
					$Cmd='"' & $7za & '" e "' & _StringVerifyAscII($g_DownDir) & '\' & $Save & '" -aoa -o"' & _StringVerifyAscII($Path) & '"'
				Else
					$Path=$g_BG2Dir & '\infinityanimations\content'
					$Cmd='"' & $7za & '" e "' & _StringVerifyAscII($g_DownDir) & '\' & $Save & '" -aoa -o"' & _StringVerifyAscII($Path) & '"'
				EndIf
				_Process_Run($Cmd, '7z.exe')
				If Not StringInStr($g_ConsoleOutput, 'Everything is Ok') Then IniWrite($g_BWSIni, 'Faults', 'IAContent'&$c, 1); leave an error
			EndIf
		Next
		_FileSearchDelete($g_BG2Dir & '\infinityanimations\restore', '*', 'D'); remove the empty folders
		_FileSearchDelete($g_BG2Dir & '\infinityanimations\content', '*', 'D'); remove the empty folders
		If StringRegExp($IATest[0][1], '\x7c(02|03|04|05|06|07|09|10|11|12|13|14)\x7c') Then; archive contains extended ascii/ansi
			Local $IATest[8]=[7, 162, 163, 181, 198, 216, 230, 248]; these are characters that are used
			$Found=0
			For $i=1 to $IATest[0]
				If FileExists($g_BG2Dir&'\infinityanimations\content\'&Chr($IATest[$i])&'*') Then; found one => codepage should be ok
					$Found=1
					ExitLoop
				EndIf
			Next
			If $Found = 0 Then; possible codepage-error
				$String=''
				For $i=1 to $IATest[0]
					$String&=' '&Chr($IATest[$i])
				Next
				$String=StringTrimLeft($String, 1)
				$Answer = _Misc_MsgGUI(3, _GetTR($g_UI_Message, '0-T1'), StringFormat(_IniRead($Message, 'L8', ''), $String, 'infinityanimations\content'), 2); => not all files were found
				If $Answer = 1 Then Exit
			EndIf
		EndIf
	EndIf
; ================         move files from sub-directories to main     ================
	If StringRegExp($g_Flags[14], 'BWP|BWS') And FileExists($g_GameDir&'\A4Auror') Then
		FileWrite($g_LogFile, '>A4Auror\* .' & @CRLF)
		FileMove($g_BG2Dir&'\A4Auror\Setup-A4Auror.exe', $g_BG2Dir&'\Setup-A4Auror.exe')
	EndIf
	If FileExists($g_GameDir&'\randomiser') Then
		$TP2Exists = _Test_GetCustomTP2('randomiser', '\randomiser\randomiser', 1); 1 = don't complain if BACKUP mod folder is not found
		If $TP2Exists <> '1' Then; randomiser.tp2 exist
			FileWrite($g_LogFile, '>randomiser\* .' & @CRLF)
			_Extract_MoveModEx('randomiser')
		EndIf
	EndIf
	If FileExists($g_GameDir&'\CtBv1.13a\CtBv1.13') Then
		$TP2Exists = _Test_GetCustomTP2('CTB', '\CtBv1.13a\CtBv1.13\', 1); 1 = don't complain if BACKUP mod folder is not found
		If $TP2Exists <> '0' Then; this is a folder
			FileWrite($g_LogFile, '>CtBv1.13a\CtBv1.13\* .' & @CRLF)
			_Extract_MoveMod('CtBv1.13a\CtBv1.13')
		EndIf
	EndIf
	If StringRegExp($g_Flags[14], 'BWP|BWS') And FileExists($g_GameDir&'\InifKit') Then
		FileWrite($g_LogFile, '>InifKit\* .' & @CRLF)
		_Extract_MoveMod('InifKit')
	EndIf
	If StringRegExp($g_Flags[14], 'BWP|BWS') And FileExists($g_GameDir&'\Keenmarker') Then
		FileWrite($g_LogFile, '>Keenmarker\* .' & @CRLF)
		_Extract_MoveMod('Keenmarker')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BiG-World-Fixpack-master') Then
		FileWrite($g_LogFile, '>BiG-World-Fixpack-master\* .' & @CRLF)
		_Extract_MoveMod('BiG-World-Fixpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EE-Mod-Fixpack-master') Then
		FileWrite($g_LogFile, '>EE-Mod-Fixpack-master\* .' & @CRLF)
		_Extract_MoveMod('EE-Mod-Fixpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BG1EE') And FileExists($g_GameDir&'\BGEE_Fix-master') Then
		FileWrite($g_LogFile, '>BGEE_Fix-master\* .' & @CRLF)
		_Extract_MoveMod('BGEE_Fix-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MSFM WeiDU Install v1.35') Then
		FileWrite($g_LogFile, '>MSFM WeiDU Install v1.35\* .' & @CRLF)
		_Extract_MoveMod('MSFM WeiDU Install v1.35')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TDD-1.14') Then
		FileWrite($g_LogFile, '>TDD-1.14\* .' & @CRLF)
		_Extract_MoveMod('TDD-1.14')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ConvenientAmmunition-1.0') Then
		FileWrite($g_LogFile, '>ConvenientAmmunition-1.0\* .' & @CRLF)
		_Extract_MoveMod('ConvenientAmmunition-1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-DlcMerger-master') Then
		FileWrite($g_LogFile, '>A7-DlcMerger-master\* .' & @CRLF)
		_Extract_MoveMod('A7-DlcMerger-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bg1ub-master') Then
		FileWrite($g_LogFile, '>bg1ub-master\* .' & @CRLF)
		_Extract_MoveMod('bg1ub-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CandlekeepMemories-master') Then
		FileWrite($g_LogFile, '>CandlekeepMemories-master\* .' & @CRLF)
		_Extract_MoveMod('CandlekeepMemories-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HollytheElf-master') Then
		FileWrite($g_LogFile, '>HollytheElf-master\* .' & @CRLF)
		_Extract_MoveMod('HollytheElf-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DrowLibrary-master') Then
		FileWrite($g_LogFile, '>DrowLibrary-master\* .' & @CRLF)
		_Extract_MoveMod('DrowLibrary-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Velvetfoot-master') Then
		FileWrite($g_LogFile, '>Velvetfoot-master\* .' & @CRLF)
		_Extract_MoveMod('Velvetfoot-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SpeakDead-master') Then
		FileWrite($g_LogFile, '>SpeakDead-master\* .' & @CRLF)
		_Extract_MoveMod('SpeakDead-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MalteseArtefact-master') Then
		FileWrite($g_LogFile, '>MalteseArtefact-master\* .' & @CRLF)
		_Extract_MoveMod('MalteseArtefact-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CivilDisobedience-master') Then
		FileWrite($g_LogFile, '>CivilDisobedience-master\* .' & @CRLF)
		_Extract_MoveMod('CivilDisobedience-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MelyndaMute-master') Then
		FileWrite($g_LogFile, '>MelyndaMute-master\* .' & @CRLF)
		_Extract_MoveMod('MelyndaMute-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BearWalkerKit-master') Then
		FileWrite($g_LogFile, '>BearWalkerKit-master\* .' & @CRLF)
		_Extract_MoveMod('BearWalkerKit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Drake-master') Then
		FileWrite($g_LogFile, '>Drake-master\* .' & @CRLF)
		_Extract_MoveMod('Drake-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Gavin_BG-master') Then
		FileWrite($g_LogFile, '>Gavin_BG-master\* .' & @CRLF)
		_Extract_MoveMod('Gavin_BG-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Isra_NPC_BG2-3.1') Then
		FileWrite($g_LogFile, '>Isra_NPC_BG2-3.1\* .' & @CRLF)
		_Extract_MoveMod('Isra_NPC_BG2-3.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Isra_NPC-3.5') Then
		FileWrite($g_LogFile, '>Isra_NPC-3.5\* .' & @CRLF)
		_Extract_MoveMod('Isra_NPC-3.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sirene-NPC-master') Then
		FileWrite($g_LogFile, '>Sirene-NPC-master\* .' & @CRLF)
		_Extract_MoveMod('Sirene-NPC-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Kim_Pirate-master') Then
		FileWrite($g_LogFile, '>Kim_Pirate-master\* .' & @CRLF)
		_Extract_MoveMod('Kim_Pirate-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HaveIce-master') Then
		FileWrite($g_LogFile, '>HaveIce-master\* .' & @CRLF)
		_Extract_MoveMod('HaveIce-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MasterVampire-master') Then
		FileWrite($g_LogFile, '>MasterVampire-master\* .' & @CRLF)
		_Extract_MoveMod('MasterVampire-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BG1NPC-27') Then
		FileWrite($g_LogFile, '>BG1NPC-27\* .' & @CRLF)
		_Extract_MoveMod('BG1NPC-27')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bg1npcmusic-master') Then
		FileWrite($g_LogFile, '>bg1npcmusic-master\* .' & @CRLF)
		_Extract_MoveMod('bg1npcmusic-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CoranBGFriend-5') Then
		FileWrite($g_LogFile, '>CoranBGFriend-5\* .' & @CRLF)
		_Extract_MoveMod('CoranBGFriend-5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SheenaHD-master') Then
		FileWrite($g_LogFile, '>SheenaHD-master\* .' & @CRLF)
		_Extract_MoveMod('SheenaHD-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TheSwordofNoober-2.1.0') Then
		FileWrite($g_LogFile, '>TheSwordofNoober-2.1.0\* .' & @CRLF)
		_Extract_MoveMod('TheSwordofNoober-2.1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\NoSoDSound-master') Then
		FileWrite($g_LogFile, '>NoSoDSound-master\* .' & @CRLF)
		_Extract_MoveMod('NoSoDSound-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CowledMenace-master') Then
		FileWrite($g_LogFile, '>CowledMenace-master\* .' & @CRLF)
		_Extract_MoveMod('CowledMenace-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AstroBryGuy-NeeraBanters-7124366') Then
		FileWrite($g_LogFile, '>AstroBryGuy-NeeraBanters-7124366\* .' & @CRLF)
		_Extract_MoveMod('AstroBryGuy-NeeraBanters-7124366')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\m7tweaks-master') Then
		FileWrite($g_LogFile, '>m7tweaks-master\* .' & @CRLF)
		_Extract_MoveMod('m7tweaks-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sampsca-ThrownHammers-20eb91a') Then
		FileWrite($g_LogFile, '>Sampsca-ThrownHammers-20eb91a\* .' & @CRLF)
		_Extract_MoveMod('Sampsca-ThrownHammers-20eb91a')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TheBeaurinLegacy-master') Then
		FileWrite($g_LogFile, '>TheBeaurinLegacy-master\* .' & @CRLF)
		_Extract_MoveMod('TheBeaurinLegacy-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Indira-master') Then
		FileWrite($g_LogFile, '>Indira-master\* .' & @CRLF)
		_Extract_MoveMod('Indira-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Finch-master') Then
		FileWrite($g_LogFile, '>Finch-master\* .' & @CRLF)
		_Extract_MoveMod('Finch-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EET-master') Then
		FileWrite($g_LogFile, '>EET-master\* .' & @CRLF)
		_Extract_MoveMod('EET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AC_QUEST-3.0') Then
		FileWrite($g_LogFile, '>AC_QUEST-3.0\* .' & @CRLF)
		_Extract_MoveMod('AC_QUEST-3.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AjocMod-master') Then
		FileWrite($g_LogFile, '>AjocMod-master\* .' & @CRLF)
		_Extract_MoveMod('AjocMod-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ACBre-master') Then
		FileWrite($g_LogFile, '>ACBre-master\* .' & @CRLF)
		_Extract_MoveMod('ACBre-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Aura_BG1-master') Then
		FileWrite($g_LogFile, '>Aura_BG1-master\* .' & @CRLF)
		_Extract_MoveMod('Aura_BG1-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DarkHorizonsTweaks-master') Then
		FileWrite($g_LogFile, '>DarkHorizonsTweaks-master\* .' & @CRLF)
		_Extract_MoveMod('DarkHorizonsTweaks-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EET_Tweaks-master') Then
		FileWrite($g_LogFile, '>EET_Tweaks-master\* .' & @CRLF)
		_Extract_MoveMod('EET_Tweaks-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Olvyn-Tweaks-master') Then
		FileWrite($g_LogFile, '>Olvyn-Tweaks-master\* .' & @CRLF)
		_Extract_MoveMod('Olvyn-Tweaks-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AzengaardEE-master') Then
		FileWrite($g_LogFile, '>AzengaardEE-master\* .' & @CRLF)
		_Extract_MoveMod('AzengaardEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ToA-3.1') Then
		FileWrite($g_LogFile, '>ToA-3.1\* .' & @CRLF)
		_Extract_MoveMod('ToA-3.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\FishingForTrouble-3.2.7') Then
		FileWrite($g_LogFile, '>FishingForTrouble-3.2.7\* .' & @CRLF)
		_Extract_MoveMod('FishingForTrouble-3.2.7')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Magestronghold-0.4') Then
		FileWrite($g_LogFile, '>Magestronghold-0.4\* .' & @CRLF)
		_Extract_MoveMod('Magestronghold-0.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MilitiaOfficer-Kit-master') Then
		FileWrite($g_LogFile, '>MilitiaOfficer-Kit-master\* .' & @CRLF)
		_Extract_MoveMod('MilitiaOfficer-Kit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SoD-to-BG2EE-Item-Upgrade-master') Then
		FileWrite($g_LogFile, '>SoD-to-BG2EE-Item-Upgrade-master\* .' & @CRLF)
		_Extract_MoveMod('SoD-to-BG2EE-Item-Upgrade-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Mercenary-Kit-master') Then
		FileWrite($g_LogFile, '>Mercenary-Kit-master\* .' & @CRLF)
		_Extract_MoveMod('Mercenary-Kit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ImnesvaleEE-master') Then
		FileWrite($g_LogFile, '>ImnesvaleEE-master\* .' & @CRLF)
		_Extract_MoveMod('ImnesvaleEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-TestYourMettle-master') Then
		FileWrite($g_LogFile, '>A7-TestYourMettle-master\* .' & @CRLF)
		_Extract_MoveMod('A7-TestYourMettle-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-ResizeableCombatLog-master') Then
		FileWrite($g_LogFile, '>A7-ResizeableCombatLog-master\* .' & @CRLF)
		_Extract_MoveMod('A7-ResizeableCombatLog-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\hiddenadventure-master') Then
		FileWrite($g_LogFile, '>hiddenadventure-master\* .' & @CRLF)
		_Extract_MoveMod('hiddenadventure-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\d5_Random_Tweaks-1.1') Then
		FileWrite($g_LogFile, '>d5_Random_Tweaks-1.1\* .' & @CRLF)
		_Extract_MoveMod('d5_Random_Tweaks-1.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-LightingPackEE-master') Then
		FileWrite($g_LogFile, '>A7-LightingPackEE-master\* .' & @CRLF)
		_Extract_MoveMod('A7-LightingPackEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AloraEE-master') Then
		FileWrite($g_LogFile, '>AloraEE-master\* .' & @CRLF)
		_Extract_MoveMod('AloraEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-HiddenGameplayOptions-master') Then
		FileWrite($g_LogFile, '>A7-HiddenGameplayOptions-master\* .' & @CRLF)
		_Extract_MoveMod('A7-HiddenGameplayOptions-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Balduran-s-Sea-Tower-master') Then
		FileWrite($g_LogFile, '>Balduran-s-Sea-Tower-master\* .' & @CRLF)
		_Extract_MoveMod('Balduran-s-Sea-Tower-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Gorion-s-Dream-master') Then
		FileWrite($g_LogFile, '>Gorion-s-Dream-master\* .' & @CRLF)
		_Extract_MoveMod('Gorion-s-Dream-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Alternatives-master') Then
		FileWrite($g_LogFile, '>Alternatives-master\* .' & @CRLF)
		_Extract_MoveMod('Alternatives-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Haldamir-master') Then
		FileWrite($g_LogFile, '>Haldamir-master\* .' & @CRLF)
		_Extract_MoveMod('Haldamir-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\haerdalisromance-master') Then
		FileWrite($g_LogFile, '>haerdalisromance-master\* .' & @CRLF)
		_Extract_MoveMod('haerdalisromance-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Angelo-master') Then
		FileWrite($g_LogFile, '>Angelo-master\* .' & @CRLF)
		_Extract_MoveMod('Angelo-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Corthala_Romantique-master') Then
		FileWrite($g_LogFile, '>Corthala_Romantique-master\* .' & @CRLF)
		_Extract_MoveMod('Corthala_Romantique-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ThePictureStandard-master') Then
		FileWrite($g_LogFile, '>ThePictureStandard-master\* .' & @CRLF)
		_Extract_MoveMod('ThePictureStandard-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Ascension-master') Then
		FileWrite($g_LogFile, '>Ascension-master\* .' & @CRLF)
		_Extract_MoveMod('Ascension-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MadeInHeaven_ItemPack-master') Then
		FileWrite($g_LogFile, '>MadeInHeaven_ItemPack-master\* .' & @CRLF)
		_Extract_MoveMod('MadeInHeaven_ItemPack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ArienaEE-3.0') Then
		FileWrite($g_LogFile, '>ArienaEE-3.0\* .' & @CRLF)
		_Extract_MoveMod('ArienaEE-3.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bg2-npcmod-lena-0.8') Then
		FileWrite($g_LogFile, '>bg2-npcmod-lena-0.8\* .' & @CRLF)
		_Extract_MoveMod('bg2-npcmod-lena-0.8')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BGEESpawn-master') Then
		FileWrite($g_LogFile, '>BGEESpawn-master\* .' & @CRLF)
		_Extract_MoveMod('BGEESpawn-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Caelar-1.2') Then
		FileWrite($g_LogFile, '>Caelar-1.2\* .' & @CRLF)
		_Extract_MoveMod('Caelar-1.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\The-Rune-master') Then
		FileWrite($g_LogFile, '>The-Rune-master\* .' & @CRLF)
		_Extract_MoveMod('The-Rune-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ChloeEET-1.7_EE') Then
		FileWrite($g_LogFile, '>ChloeEET-1.7_EE\* .' & @CRLF)
		_Extract_MoveMod('ChloeEET-1.7_EE')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Corwin-1.1') Then
		FileWrite($g_LogFile, '>Corwin-1.1\* .' & @CRLF)
		_Extract_MoveMod('Corwin-1.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Subrace-mod-0.2.1') Then
		FileWrite($g_LogFile, '>Subrace-mod-0.2.1\* .' & @CRLF)
		_Extract_MoveMod('Subrace-mod-0.2.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Crossmod_Banter_Pack_for_Baldurs_Gate_II-master') Then
		FileWrite($g_LogFile, '>Crossmod_Banter_Pack_for_Baldurs_Gate_II-master\* .' & @CRLF)
		_Extract_MoveMod('Crossmod_Banter_Pack_for_Baldurs_Gate_II-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SandrahEET-master') Then
		FileWrite($g_LogFile, '>SandrahEET-master\* .' & @CRLF)
		_Extract_MoveMod('SandrahEET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SandrahRtF-master') Then
		FileWrite($g_LogFile, '>SandrahRtF-master\* .' & @CRLF)
		_Extract_MoveMod('SandrahRtF-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DaceEET-master') Then
		FileWrite($g_LogFile, '>DaceEET-master\* .' & @CRLF)
		_Extract_MoveMod('DaceEET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Check_the_Bodies-3.0') Then
		FileWrite($g_LogFile, '>Check_the_Bodies-3.0\* .' & @CRLF)
		_Extract_MoveMod('Check_the_Bodies-3.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EET_Fixpack-master') Then
		FileWrite($g_LogFile, '>EET_Fixpack-master\* .' & @CRLF)
		_Extract_MoveMod('EET_Fixpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EET_Expanded_Thief_Stronghold-2.3') Then
		FileWrite($g_LogFile, '>EET_Expanded_Thief_Stronghold-2.3\* .' & @CRLF)
		_Extract_MoveMod('EET_Expanded_Thief_Stronghold-2.3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DSotSC-4.1') Then
		FileWrite($g_LogFile, '>DSotSC-4.1\* .' & @CRLF)
		_Extract_MoveMod('DSotSC-4.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DeepgnomesEET-0.4') Then
		FileWrite($g_LogFile, '>DeepgnomesEET-0.4\* .' & @CRLF)
		_Extract_MoveMod('DeepgnomesEET-0.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DjinniCompanion-master') Then
		FileWrite($g_LogFile, '>DjinniCompanion-master\* .' & @CRLF)
		_Extract_MoveMod('DjinniCompanion-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DruidGroveMakeover-1.2') Then
		FileWrite($g_LogFile, '>DruidGroveMakeover-1.2\* .' & @CRLF)
		_Extract_MoveMod('DruidGroveMakeover-1.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Edwin_Romance-2.11') Then
		FileWrite($g_LogFile, '>Edwin_Romance-2.11\* .' & @CRLF)
		_Extract_MoveMod('Edwin_Romance-2.11')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EEUITweaks-3.6') Then
		FileWrite($g_LogFile, '>EEUITweaks-3.6\* .' & @CRLF)
		_Extract_MoveMod('EEUITweaks-3.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\EEUITweaks-3.5') Then
		FileWrite($g_LogFile, '>EEUITweaks-3.5\* .' & @CRLF)
		_Extract_MoveMod('EEUITweaks-3.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Baldurs-gate-dnd-3.5-2.16.5') Then
		FileWrite($g_LogFile, '>Baldurs-gate-dnd-3.5-2.16.5\* .' & @CRLF)
		_Extract_MoveMod('Baldurs-gate-dnd-3.5-2.16.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HaerDalis_Swords-3.1.0') Then
		FileWrite($g_LogFile, '>HaerDalis_Swords-3.1.0\* .' & @CRLF)
		_Extract_MoveMod('HaerDalis_Swords-3.1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Neera_Expansion-1.3.0') Then
		FileWrite($g_LogFile, '>Neera_Expansion-1.3.0\* .' & @CRLF)
		_Extract_MoveMod('Neera_Expansion-1.3.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\artaport-master') Then
		FileWrite($g_LogFile, '>artaport-master\* .' & @CRLF)
		_Extract_MoveMod('artaport-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\PST-UB-reloaded-master') Then
		FileWrite($g_LogFile, '>PST-UB-reloaded-master\* .' & @CRLF)
		_Extract_MoveMod('PST-UB-reloaded-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\generalized_biffing-master') Then
		FileWrite($g_LogFile, '>generalized_biffing-master\* .' & @CRLF)
		_Extract_MoveMod('generalized_biffing-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-BagsOfTorment-master') Then
		FileWrite($g_LogFile, '>A7-BagsOfTorment-master\* .' & @CRLF)
		_Extract_MoveMod('A7-BagsOfTorment-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Ajantis_BG1_Expansion-17') Then
		FileWrite($g_LogFile, '>Ajantis_BG1_Expansion-17\* .' & @CRLF)
		_Extract_MoveMod('Ajantis_BG1_Expansion-17')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\StuffofTheMagi-6.0.0') Then
		FileWrite($g_LogFile, '>StuffofTheMagi-6.0.0\* .' & @CRLF)
		_Extract_MoveMod('StuffofTheMagi-6.0.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\amber-master') Then
		FileWrite($g_LogFile, '>amber-master\* .' & @CRLF)
		_Extract_MoveMod('amber-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Rolles-5.0.5') Then
		FileWrite($g_LogFile, '>Rolles-5.0.5\* .' & @CRLF)
		_Extract_MoveMod('Rolles-5.0.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\g3anniversary-master') Then
		FileWrite($g_LogFile, '>g3anniversary-master\* .' & @CRLF)
		_Extract_MoveMod('g3anniversary-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Hubelpot_the_Vegetable_Merchant_NPC-2.1.0') Then
		FileWrite($g_LogFile, '>Hubelpot_the_Vegetable_Merchant_NPC-2.1.0\* .' & @CRLF)
		_Extract_MoveMod('Hubelpot_the_Vegetable_Merchant_NPC-2.1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HQ-SoundClips-BG2EE-master') Then
		FileWrite($g_LogFile, '>HQ-SoundClips-BG2EE-master\* .' & @CRLF)
		_Extract_MoveMod('HQ-SoundClips-BG2EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Gavin_BG2-master') Then
		FileWrite($g_LogFile, '>Gavin_BG2-master\* .' & @CRLF)
		_Extract_MoveMod('Gavin_BG2-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Hlondeth-master') Then
		FileWrite($g_LogFile, '>Hlondeth-master\* .' & @CRLF)
		_Extract_MoveMod('Hlondeth-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AstroBryGuy-JaheiraRecast-501290c') Then
		FileWrite($g_LogFile, '>AstroBryGuy-JaheiraRecast-501290c\* .' & @CRLF)
		_Extract_MoveMod('AstroBryGuy-JaheiraRecast-501290c')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Portraits-Portraits-Everywhere-master') Then
		FileWrite($g_LogFile, '>Portraits-Portraits-Everywhere-master\* .' & @CRLF)
		_Extract_MoveMod('Portraits-Portraits-Everywhere-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Imoen4Ever-3') Then
		FileWrite($g_LogFile, '>Imoen4Ever-3\* .' & @CRLF)
		_Extract_MoveMod('Imoen4Ever-3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\iwdification-master') Then
		FileWrite($g_LogFile, '>iwdification-master\* .' & @CRLF)
		_Extract_MoveMod('iwdification-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Gibberlings3-NPCTweak-5a84301') Then
		FileWrite($g_LogFile, '>Gibberlings3-NPCTweak-5a84301\* .' & @CRLF)
		_Extract_MoveMod('Gibberlings3-NPCTweak-5a84301')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\IylosEET-master') Then
		FileWrite($g_LogFile, '>IylosEET-master\* .' & @CRLF)
		_Extract_MoveMod('IylosEET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\KidoEE-master') Then
		FileWrite($g_LogFile, '>KidoEE-master\* .' & @CRLF)
		_Extract_MoveMod('KidoEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Lore_From_Learning-3') Then
		FileWrite($g_LogFile, '>Lore_From_Learning-3\* .' & @CRLF)
		_Extract_MoveMod('Lore_From_Learning-3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Keldorn_Romance-master') Then
		FileWrite($g_LogFile, '>Keldorn_Romance-master\* .' & @CRLF)
		_Extract_MoveMod('Keldorn_Romance-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-ImprovedArcher-master') Then
		FileWrite($g_LogFile, '>A7-ImprovedArcher-master\* .' & @CRLF)
		_Extract_MoveMod('A7-ImprovedArcher-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Kitanya-Resurrected-master') Then
		FileWrite($g_LogFile, '>Kitanya-Resurrected-master\* .' & @CRLF)
		_Extract_MoveMod('Kitanya-Resurrected-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LongerRoadEE-1.9') Then
		FileWrite($g_LogFile, '>LongerRoadEE-1.9\* .' & @CRLF)
		_Extract_MoveMod('LongerRoadEE-1.9')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\NindeEET-master') Then
		FileWrite($g_LogFile, '>NindeEET-master\* .' & @CRLF)
		_Extract_MoveMod('NindeEET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Tsujatha-master') Then
		FileWrite($g_LogFile, '>Tsujatha-master\* .' & @CRLF)
		_Extract_MoveMod('Tsujatha-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SOS_EE-master') Then
		FileWrite($g_LogFile, '>SOS_EE-master\* .' & @CRLF)
		_Extract_MoveMod('SOS_EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\YasraenaEET-19') Then
		FileWrite($g_LogFile, '>YasraenaEET-19\* .' & @CRLF)
		_Extract_MoveMod('YasraenaEET-19')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Faiths_and_Powers-master') Then
		FileWrite($g_LogFile, '>Faiths_and_Powers-master\* .' & @CRLF)
		_Extract_MoveMod('Faiths_and_Powers-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SongAndSilence-master') Then
		FileWrite($g_LogFile, '>SongAndSilence-master\* .' & @CRLF)
		_Extract_MoveMod('SongAndSilence-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Item_Upgrade-master') Then
		FileWrite($g_LogFile, '>Item_Upgrade-master\* .' & @CRLF)
		_Extract_MoveMod('Item_Upgrade-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LensHunt-master') Then
		FileWrite($g_LogFile, '>LensHunt-master\* .' & @CRLF)
		_Extract_MoveMod('LensHunt-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\WTPFamiliars-master') Then
		FileWrite($g_LogFile, '>WTPFamiliars-master\* .' & @CRLF)
		_Extract_MoveMod('WTPFamiliars-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\NTotSC-master') Then
		FileWrite($g_LogFile, '>NTotSC-master\* .' & @CRLF)
		_Extract_MoveMod('NTotSC-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\msfm-1.57') Then
		FileWrite($g_LogFile, '>msfm-1.57\* .' & @CRLF)
		_Extract_MoveMod('msfm-1.57')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Romantic_Encounters_BG2-master') Then
		FileWrite($g_LogFile, '>Romantic_Encounters_BG2-master\* .' & @CRLF)
		_Extract_MoveMod('Romantic_Encounters_BG2-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BG1_Romantic_Encounters-6.0') Then
		FileWrite($g_LogFile, '>BG1_Romantic_Encounters-6.0\* .' & @CRLF)
		_Extract_MoveMod('BG1_Romantic_Encounters-6.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\RoseRE-master') Then
		FileWrite($g_LogFile, '>RoseRE-master\* .' & @CRLF)
		_Extract_MoveMod('RoseRE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\RoT-master') Then
		FileWrite($g_LogFile, '>RoT-master\* .' & @CRLF)
		_Extract_MoveMod('RoT-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BoneHill-32') Then
		FileWrite($g_LogFile, '>BoneHill-32\* .' & @CRLF)
		_Extract_MoveMod('BoneHill-32')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Saerileth-master') Then
		FileWrite($g_LogFile, '>Saerileth-master\* .' & @CRLF)
		_Extract_MoveMod('Saerileth-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SafanaBG2-master') Then
		FileWrite($g_LogFile, '>SafanaBG2-master\* .' & @CRLF)
		_Extract_MoveMod('SafanaBG2-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sirene-NPC-for-BG2-EE-master') Then
		FileWrite($g_LogFile, '>Sirene-NPC-for-BG2-EE-master\* .' & @CRLF)
		_Extract_MoveMod('Sirene-NPC-for-BG2-EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SoDBanterEET-0.6') Then
		FileWrite($g_LogFile, '>SoDBanterEET-0.6\* .' & @CRLF)
		_Extract_MoveMod('SoDBanterEET-0.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SwordCoastStratagems-33.7') Then
		FileWrite($g_LogFile, '>SwordCoastStratagems-33.7\* .' & @CRLF)
		_Extract_MoveMod('SwordCoastStratagems-33.7')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Tamoko-0.7') Then
		FileWrite($g_LogFile, '>Tamoko-0.7\* .' & @CRLF)
		_Extract_MoveMod('Tamoko-0.7')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TDDz-1.5') Then
		FileWrite($g_LogFile, '>TDDz-1.5\* .' & @CRLF)
		_Extract_MoveMod('TDDz-1.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TGC1e-master') Then
		FileWrite($g_LogFile, '>TGC1e-master\* .' & @CRLF)
		_Extract_MoveMod('TGC1e-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\thalan-4.2.4') Then
		FileWrite($g_LogFile, '>thalan-4.2.4\* .' & @CRLF)
		_Extract_MoveMod('thalan-4.2.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\RuadEE-master') Then
		FileWrite($g_LogFile, '>RuadEE-master\* .' & @CRLF)
		_Extract_MoveMod('RuadEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\NPC_EE-4.3') Then
		FileWrite($g_LogFile, '>NPC_EE-4.3\* .' & @CRLF)
		_Extract_MoveMod('NPC_EE-4.3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TowerOfDeception-5.0.1') Then
		FileWrite($g_LogFile, '>TowerOfDeception-5.0.1\* .' & @CRLF)
		_Extract_MoveMod('TowerOfDeception-5.0.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Pai-Na-NPC-mod-for-BG2-EE-master') Then
		FileWrite($g_LogFile, '>Pai-Na-NPC-mod-for-BG2-EE-master\* .' & @CRLF)
		_Extract_MoveMod('Pai-Na-NPC-mod-for-BG2-EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Tweaks-Anthology-9') Then
		FileWrite($g_LogFile, '>Tweaks-Anthology-9\* .' & @CRLF)
		_Extract_MoveMod('Tweaks-Anthology-9')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TyrisEE-master') Then
		FileWrite($g_LogFile, '>TyrisEE-master\* .' & @CRLF)
		_Extract_MoveMod('TyrisEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\randomiser-master') Then
		FileWrite($g_LogFile, '>randomiser-master\* .' & @CRLF)
		_Extract_MoveMod('randomiser-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\UnfinishedBusiness-master') Then
		FileWrite($g_LogFile, '>UnfinishedBusiness-master\* .' & @CRLF)
		_Extract_MoveMod('UnfinishedBusiness-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\iwd_unfinished_business-master') Then
		FileWrite($g_LogFile, '>iwd_unfinished_business-master\* .' & @CRLF)
		_Extract_MoveMod('iwd_unfinished_business-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\iwd_portrait_variations-master') Then
		FileWrite($g_LogFile, '>iwd_portrait_variations-master\* .' & @CRLF)
		_Extract_MoveMod('iwd_portrait_variations-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\The-Artisan-s-Kitpack-master') Then
		FileWrite($g_LogFile, '>The-Artisan-s-Kitpack-master\* .' & @CRLF)
		_Extract_MoveMod('The-Artisan-s-Kitpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Valerie_NPC-1.2') Then
		FileWrite($g_LogFile, '>Valerie_NPC-1.2\* .' & @CRLF)
		_Extract_MoveMod('Valerie_NPC-1.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ValenEE-master') Then
		FileWrite($g_LogFile, '>ValenEE-master\* .' & @CRLF)
		_Extract_MoveMod('ValenEE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\VaultEE-8.1') Then
		FileWrite($g_LogFile, '>VaultEE-8.1\* .' & @CRLF)
		_Extract_MoveMod('VaultEE-8.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\WheelsOfProphecy-master') Then
		FileWrite($g_LogFile, '>WheelsOfProphecy-master\* .' & @CRLF)
		_Extract_MoveMod('WheelsOfProphecy-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\XulayeEet-2.3') Then
		FileWrite($g_LogFile, '>XulayeEet-2.3\* .' & @CRLF)
		_Extract_MoveMod('XulayeEet-2.3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\jimfix-master') Then
		FileWrite($g_LogFile, '>jimfix-master\* .' & @CRLF)
		_Extract_MoveMod('jimfix-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SandrahToT-master') Then
		FileWrite($g_LogFile, '>SandrahToT-master\* .' & @CRLF)
		_Extract_MoveMod('SandrahToT-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Shards_of_Ice-master') Then
		FileWrite($g_LogFile, '>Shards_of_Ice-master\* .' & @CRLF)
		_Extract_MoveMod('Shards_of_Ice-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Kivan_and_Deheriana-master') Then
		FileWrite($g_LogFile, '>Kivan_and_Deheriana-master\* .' & @CRLF)
		_Extract_MoveMod('Kivan_and_Deheriana-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Gibberlings3-Anishai-c1368e4') Then
		FileWrite($g_LogFile, '>Gibberlings3-Anishai-c1368e4\* .' & @CRLF)
		_Extract_MoveMod('Gibberlings3-Anishai-c1368e4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\GwendolyneFreddy-butchery-d7d154c') Then
		FileWrite($g_LogFile, '>GwendolyneFreddy-butchery-d7d154c\* .' & @CRLF)
		_Extract_MoveMod('GwendolyneFreddy-butchery-d7d154c')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Solaufeins_Rescue_NPC-2Beta') Then
		FileWrite($g_LogFile, '>Solaufeins_Rescue_NPC-2Beta\* .' & @CRLF)
		_Extract_MoveMod('Solaufeins_Rescue_NPC-2Beta')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\PnP_Celestials-master') Then
		FileWrite($g_LogFile, '>PnP_Celestials-master\* .' & @CRLF)
		_Extract_MoveMod('PnP_Celestials-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AnimalCompanions-master') Then
		FileWrite($g_LogFile, '>AnimalCompanions-master\* .' & @CRLF)
		_Extract_MoveMod('AnimalCompanions-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-BanterAccelerator-master') Then
		FileWrite($g_LogFile, '>A7-BanterAccelerator-master\* .' & @CRLF)
		_Extract_MoveMod('A7-BanterAccelerator-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-NPCGenerator-1.2') Then
		FileWrite($g_LogFile, '>A7-NPCGenerator-1.2\* .' & @CRLF)
		_Extract_MoveMod('A7-NPCGenerator-1.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Divine_Remix-master') Then
		FileWrite($g_LogFile, '>Divine_Remix-master\* .' & @CRLF)
		_Extract_MoveMod('Divine_Remix-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Nephele_NPC-2.6') Then
		FileWrite($g_LogFile, '>Nephele_NPC-2.6\* .' & @CRLF)
		_Extract_MoveMod('Nephele_NPC-2.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Epic-Thieving-master') Then
		FileWrite($g_LogFile, '>Epic-Thieving-master\* .' & @CRLF)
		_Extract_MoveMod('Epic-Thieving-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Geomantic_Sorcerer-master') Then
		FileWrite($g_LogFile, '>Geomantic_Sorcerer-master\* .' & @CRLF)
		_Extract_MoveMod('Geomantic_Sorcerer-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Bg2Dorn-master') Then
		FileWrite($g_LogFile, '>Bg2Dorn-master\* .' & @CRLF)
		_Extract_MoveMod('Bg2Dorn-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Fade_NPC-5.6') Then
		FileWrite($g_LogFile, '>Fade_NPC-5.6\* .' & @CRLF)
		_Extract_MoveMod('Fade_NPC-5.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BP-BGT-Worldmap-10.2.5') Then
		FileWrite($g_LogFile, '>BP-BGT-Worldmap-10.2.5\* .' & @CRLF)
		_Extract_MoveMod('BP-BGT-Worldmap-10.2.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Relieve-Wizard-Slayer-master') Then
		FileWrite($g_LogFile, '>Relieve-Wizard-Slayer-master\* .' & @CRLF)
		_Extract_MoveMod('Relieve-Wizard-Slayer-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-GolemConstruction-master') Then
		FileWrite($g_LogFile, '>A7-GolemConstruction-master\* .' & @CRLF)
		_Extract_MoveMod('A7-GolemConstruction-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SpiritHunterShamantKit-master') Then
		FileWrite($g_LogFile, '>SpiritHunterShamantKit-master\* .' & @CRLF)
		_Extract_MoveMod('SpiritHunterShamantKit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\JansAlchemy-8.1.0') Then
		FileWrite($g_LogFile, '>JansAlchemy-8.1.0\* .' & @CRLF)
		_Extract_MoveMod('JansAlchemy-8.1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LeUI-master') Then
		FileWrite($g_LogFile, '>LeUI-master\* .' & @CRLF)
		_Extract_MoveMod('LeUI-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LeUI-BG1EE-master') Then
		FileWrite($g_LogFile, '>LeUI-BG1EE-master\* .' & @CRLF)
		_Extract_MoveMod('LeUI-BG1EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LeUI-IWDEE-1.9.1') Then
		FileWrite($g_LogFile, '>LeUI-LeUI-IWDEE-1.9.1\* .' & @CRLF)
		_Extract_MoveMod('LeUI-IWDEE-1.9.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\LeUI-SoD-master') Then
		FileWrite($g_LogFile, '>LeUI-SoD-master\* .' & @CRLF)
		_Extract_MoveMod('LeUI-SoD-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BG_Quests_And_Encounters-master') Then
		FileWrite($g_LogFile, '>BG_Quests_And_Encounters-master\* .' & @CRLF)
		_Extract_MoveMod('BG_Quests_And_Encounters-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Rupert-master') Then
		FileWrite($g_LogFile, '>Rupert-master\* .' & @CRLF)
		_Extract_MoveMod('Rupert-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ConvinientAmmunition-1.0') Then
		FileWrite($g_LogFile, '>ConvinientAmmunition-1.0\* .' & @CRLF)
		_Extract_MoveMod('ConvinientAmmunition-1.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ItemRevisions-master') Then
		FileWrite($g_LogFile, '>ItemRevisions-master\* .' & @CRLF)
		_Extract_MoveMod('ItemRevisions-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Jini Romance - v2.3') Then
		FileWrite($g_LogFile, '>Jini Romance - v2.3\* .' & @CRLF)
		_Extract_MoveMod('Jini Romance - v2.3')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SpellRevisions-4b18') Then
		FileWrite($g_LogFile, '>SpellRevisions-4b18\* .' & @CRLF)
		_Extract_MoveMod('SpellRevisions-4b18')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-ImprovedShamanicDance-master') Then
		FileWrite($g_LogFile, '>A7-ImprovedShamanicDance-master\* .' & @CRLF)
		_Extract_MoveMod('A7-ImprovedShamanicDance-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\garricks_infatuation-master') Then
		FileWrite($g_LogFile, '>garricks_infatuation-master\* .' & @CRLF)
		_Extract_MoveMod('garricks_infatuation-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\thisisulb-SpiritwalkerKit-777613d') Then
		FileWrite($g_LogFile, '>thisisulb-SpiritwalkerKit-777613d\* .' & @CRLF)
		_Extract_MoveMod('thisisulb-SpiritwalkerKit-777613d')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bg2-wildmage-2.0.0') Then
		FileWrite($g_LogFile, '>bg2-wildmage-2.0.0\* .' & @CRLF)
		_Extract_MoveMod('bg2-wildmage-2.0.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\thisisulb-SpiritwalkerKit-777613d') Then
		FileWrite($g_LogFile, '>thisisulb-SpiritwalkerKit-777613d\* .' & @CRLF)
		_Extract_MoveMod('thisisulb-SpiritwalkerKit-777613d')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-ChaosSorcerer-master') Then
		FileWrite($g_LogFile, '>A7-ChaosSorcerer-master\* .' & @CRLF)
		_Extract_MoveMod('A7-ChaosSorcerer-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DreamWalkerShamanKit-master') Then
		FileWrite($g_LogFile, '>DreamWalkerShamanKit-master\* .' & @CRLF)
		_Extract_MoveMod('DreamWalkerShamanKit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CrevsDaak-m7multikit-8f0698e') Then
		FileWrite($g_LogFile, '>CrevsDaak-m7multikit-8f0698e\* .' & @CRLF)
		_Extract_MoveMod('CrevsDaak-m7multikit-8f0698e')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\StormCallerKit-master') Then
		FileWrite($g_LogFile, '>StormCallerKit-master\* .' & @CRLF)
		_Extract_MoveMod('StormCallerKit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\I-Hate-Undead-Kitpack-master') Then
		FileWrite($g_LogFile, '>I-Hate-Undead-Kitpack-master\* .' & @CRLF)
		_Extract_MoveMod('I-Hate-Undead-Kitpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sword-and-Fist-master') Then
		FileWrite($g_LogFile, '>Sword-and-Fist-master\* .' & @CRLF)
		_Extract_MoveMod('Sword-and-Fist-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Charlatan-Kit-master') Then
		FileWrite($g_LogFile, '>Charlatan-Kit-master\* .' & @CRLF)
		_Extract_MoveMod('Charlatan-Kit-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Warlock-master') Then
		FileWrite($g_LogFile, '>Warlock-master\* .' & @CRLF)
		_Extract_MoveMod('Warlock-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Bardic-Wonders-master') Then
		FileWrite($g_LogFile, '>Bardic-Wonders-master\* .' & @CRLF)
		_Extract_MoveMod('Bardic-Wonders-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\BGEE-Classic-Movies-master') Then
		FileWrite($g_LogFile, '>BGEE-Classic-Movies-master\* .' & @CRLF)
		_Extract_MoveMod('BGEE-Classic-Movies-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\etamin-soundsets-master') Then
		FileWrite($g_LogFile, '>etamin-soundsets-master\* .' & @CRLF)
		_Extract_MoveMod('etamin-soundsets-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-recoloredbuttons-master') Then
		FileWrite($g_LogFile, '>A7-recoloredbuttons-master\* .' & @CRLF)
		_Extract_MoveMod('A7-recoloredbuttons-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\subtledoctor-EE_APR_Fix-1c6057b') Then
		FileWrite($g_LogFile, '>subtledoctor-EE_APR_Fix-1c6057b\* .' & @CRLF)
		_Extract_MoveMod('subtledoctor-EE_APR_Fix-1c6057b')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Scales_of_Balance-5.31') Then
		FileWrite($g_LogFile, '>Scales_of_Balance-5.31\* .' & @CRLF)
		_Extract_MoveMod('Scales_of_Balance-5.31')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Darron-2.0.0') Then
		FileWrite($g_LogFile, '>Darron-2.0.0\* .' & @CRLF)
		_Extract_MoveMod('Darron-2.0.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Continuous_NPC_Portraits-1') Then
		FileWrite($g_LogFile, '>Continuous_NPC_Portraits-1\* .' & @CRLF)
		_Extract_MoveMod('Continuous_NPC_Portraits-1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\KarihiNPC-master') Then
		FileWrite($g_LogFile, '>KarihiNPC-master\* .' & @CRLF)
		_Extract_MoveMod('KarihiNPC-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Solaufein-master') Then
		FileWrite($g_LogFile, '>Solaufein-master\* .' & @CRLF)
		_Extract_MoveMod('Solaufein-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MinervaNPC-master') Then
		FileWrite($g_LogFile, '>MinervaNPC-master\* .' & @CRLF)
		_Extract_MoveMod('MinervaNPC-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\A7-TotLM-BG2EE-master') Then
		FileWrite($g_LogFile, '>A7-TotLM-BG2EE-master\* .' & @CRLF)
		_Extract_MoveMod('A7-TotLM-BG2EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ViconiaFriendship-4.4') Then
		FileWrite($g_LogFile, '>ViconiaFriendship-4.4\* .' & @CRLF)
		_Extract_MoveMod('ViconiaFriendship-4.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TomeAndBlood-master') Then
		FileWrite($g_LogFile, '>TomeAndBlood-master\* .' & @CRLF)
		_Extract_MoveMod('TomeAndBlood-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Ehlastra-master') Then
		FileWrite($g_LogFile, '>Ehlastra-master\* .' & @CRLF)
		_Extract_MoveMod('Ehlastra-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sime-master') Then
		FileWrite($g_LogFile, '>Sime-master\* .' & @CRLF)
		_Extract_MoveMod('Sime-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TurnaboutEE-Master') Then
		FileWrite($g_LogFile, '>TurnaboutEE-Master\* .' & @CRLF)
		_Extract_MoveMod('TurnaboutEE-Master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SOS-EE-master') Then
		FileWrite($g_LogFile, '>SOS-EE-master\* .' & @CRLF)
		_Extract_MoveMod('SOS-EE-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\NaliaEE-6.2') Then
		FileWrite($g_LogFile, '>NaliaEE-6.2\* .' & @CRLF)
		_Extract_MoveMod('NaliaEE-6.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\DrizztSaga-3.02') Then
		FileWrite($g_LogFile, '>DrizztSaga-3.02\* .' & @CRLF)
		_Extract_MoveMod('DrizztSaga-3.02')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\refinements-4.29') Then
		FileWrite($g_LogFile, '>refinements-4.29\* .' & @CRLF)
		_Extract_MoveMod('refinements-4.29')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ArathEET-master') Then
		FileWrite($g_LogFile, '>ArathEET-master\* .' & @CRLF)
		_Extract_MoveMod('ArathEET-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Yeslick_NPC-5.0') Then
		FileWrite($g_LogFile, '>Yeslick_NPC-5.0\* .' & @CRLF)
		_Extract_MoveMod('Yeslick_NPC-5.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\The-Artisan-s-Kitpack-master') Then
		FileWrite($g_LogFile, '>The-Artisan-s-Kitpack-master\* .' & @CRLF)
		_Extract_MoveMod('The-Artisan-s-Kitpack-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SarevokFriendship-2.5') Then
		FileWrite($g_LogFile, '>SarevokFriendship-2.5\* .' & @CRLF)
		_Extract_MoveMod('SarevokFriendship-2.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Aran-Whitehand-master') Then
		FileWrite($g_LogFile, '>Aran-Whitehand-master\* .' & @CRLF)
		_Extract_MoveMod('Aran-Whitehand-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MinscFriendship-1.1') Then
		FileWrite($g_LogFile, '>MinscFriendship-1.1\* .' & @CRLF)
		_Extract_MoveMod('MinscFriendship-1.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\CerndFriendship-1.2') Then
		FileWrite($g_LogFile, '>CerndFriendship-1.2\* .' & @CRLF)
		_Extract_MoveMod('CerndFriendship-1.2')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HTaM-v.3.1') Then
		FileWrite($g_LogFile, '>HTaM-v.3.1\* .' & @CRLF)
		_Extract_MoveMod('HTaM-v.3.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Shadow-Magic-master') Then
		FileWrite($g_LogFile, '>Shadow-Magic-master\* .' & @CRLF)
		_Extract_MoveMod('Shadow-Magic-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ValygarFriendship-1.4') Then
		FileWrite($g_LogFile, '>ValygarFriendship-1.4\* .' & @CRLF)
		_Extract_MoveMod('ValygarFriendship-1.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Miriam-master') Then
		FileWrite($g_LogFile, '>Miriam-master\* .' & @CRLF)
		_Extract_MoveMod('Miriam-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Asylum-master') Then
		FileWrite($g_LogFile, '>Asylum-master\* .' & @CRLF)
		_Extract_MoveMod('Asylum-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bgee-animus-master') Then
		FileWrite($g_LogFile, '>bgee-animus-master\* .' & @CRLF)
		_Extract_MoveMod('bgee-animus-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\AurenAseph-11') Then
		FileWrite($g_LogFile, '>AurenAseph-11\* .' & @CRLF)
		_Extract_MoveMod('AurenAseph-11')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Sarah-6') Then
		FileWrite($g_LogFile, '>Sarah-6\* .' & @CRLF)
		_Extract_MoveMod('Sarah-6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Tenya-2.1') Then
		FileWrite($g_LogFile, '>Tenya-2.1\* .' & @CRLF)
		_Extract_MoveMod('Tenya-2.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Murneth-14') Then
		FileWrite($g_LogFile, '>Murneth-14\* .' & @CRLF)
		_Extract_MoveMod('Murneth-14')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Adrian_NPC-5.0') Then
		FileWrite($g_LogFile, '>Adrian_NPC-5.0\* .' & @CRLF)
		_Extract_MoveMod('Adrian_NPC-5.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Branwen_for_BGII-7') Then
		FileWrite($g_LogFile, '>Branwen_for_BGII-7\* .' & @CRLF)
		_Extract_MoveMod('Branwen_for_BGII-7')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Raduziels-Universal-Wizard-Spells-master') Then
		FileWrite($g_LogFile, '>Raduziels-Universal-Wizard-Spells-master\* .' & @CRLF)
		_Extract_MoveMod('Raduziels-Universal-Wizard-Spells-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\YoshimoFriendship-4.4') Then
		FileWrite($g_LogFile, '>YoshimoFriendship-4.4\* .' & @CRLF)
		_Extract_MoveMod('YoshimoFriendship-4.4')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\bg2-tweaks-and-tricks-master') Then
		FileWrite($g_LogFile, '>bg2-tweaks-and-tricks-master\* .' & @CRLF)
		_Extract_MoveMod('bg2-tweaks-and-tricks-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Emily-BG1-master') Then
		FileWrite($g_LogFile, '>Emily-BG1-master\* .' & @CRLF)
		_Extract_MoveMod('Emily-BG1-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Kale-BG1-master') Then
		FileWrite($g_LogFile, '>Kale-BG1-master\* .' & @CRLF)
		_Extract_MoveMod('Kale-BG1-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Vienxay-BG1-master') Then
		FileWrite($g_LogFile, '>Vienxay-BG1-master\* .' & @CRLF)
		_Extract_MoveMod('Vienxay-BG1-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Helga-BG1-master') Then
		FileWrite($g_LogFile, '>Helga-BG1-master\* .' & @CRLF)
		_Extract_MoveMod('Helga-BG1-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\SkitiaNPCs-master') Then
		FileWrite($g_LogFile, '>SkitiaNPCs-master\* .' & @CRLF)
		_Extract_MoveMod('SkitiaNPCs-master')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\MazzyFriendship-3.5') Then
		FileWrite($g_LogFile, '>MazzyFriendship-3.5\* .' & @CRLF)
		_Extract_MoveMod('MazzyFriendship-3.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\ImoenFriendship-3.6') Then
		FileWrite($g_LogFile, '>ImoenFriendship-3.6\* .' & @CRLF)
		_Extract_MoveMod('ImoenFriendship-3.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\KorganFriendship-1.6') Then
		FileWrite($g_LogFile, '>KorganFriendship-1.6\* .' & @CRLF)
		_Extract_MoveMod('KorganFriendship-1.6')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\IEP_Extended_Banter-5.7') Then
		FileWrite($g_LogFile, '>IEP_Extended_Banter-5.7\* .' & @CRLF)
		_Extract_MoveMod('IEP_Extended_Banter-5.7')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\mana_sorcerer-0.5') Then
		FileWrite($g_LogFile, '>mana_sorcerer-0.5\* .' & @CRLF)
		_Extract_MoveMod('mana_sorcerer-0.5')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\TheSlitheringMenace-4.0.0') Then
		FileWrite($g_LogFile, '>TheSlitheringMenace-4.0.0\* .' & @CRLF)
		_Extract_MoveMod('TheSlitheringMenace-4.0.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HeartOfTheWood-7.0.0') Then
		FileWrite($g_LogFile, '>HeartOfTheWood-7.0.0\* .' & @CRLF)
		_Extract_MoveMod('HeartOfTheWood-7.0.0')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\HaerdalisFriendship-1.1') Then
		FileWrite($g_LogFile, '>HaerdalisFriendship-1.1\* .' & @CRLF)
		_Extract_MoveMod('HaerdalisFriendship-1.1')
	EndIf
	If StringRegExp($g_Flags[14], 'BWS|BG1EE|BG2EE|PSTEE|IWD1EE') And FileExists($g_GameDir&'\Might_and_Guile-master') Then
		FileWrite($g_LogFile, '>Might_and_Guile-master\* .' & @CRLF)
		_Extract_MoveMod('Might_and_Guile-master')
	EndIf
; ==============  Fix textstring so weidu will not fail to install the mod ============
	If StringRegExp($g_Flags[14], 'BWP|BWS') And FileExists($g_BG2Dir&'\setup-bonehillv275.exe') Then
		$Text=FileRead($g_BG2Dir&'\bonehillv275\Language\deutsch\D\BHARRNES.TRA')
		If StringRegExp($Text, '\r\nlassen') Then
			$Text=StringReplace($Text, @CRLF&'lassen. Habt Ihr verstanden? ~ '&@CRLF, @CRLF)
			$Text=StringReplace($Text, 'werde ich Euch kommen ', 'werde ich Euch kommen lassen. Habt Ihr verstanden? ~ ')
			$Handle=FileOpen($g_BG2Dir&'\bonehillv275\Language\deutsch\D\BHARRNES.TRA', 2)
			FileWrite($Handle, $Text)
			FileClose($Handle)
		EndIf
	ElseIf $g_Flags[14]='IWD2' And FileExists($g_IWD2Dir&'\Setup-LOS.exe')	Then
		$Text=FileRead($g_IWD2Dir&'\LOS\dlg\f#bowyer.d')
		If StringInStr($Text, 'See([ENEMY], FALSE)') Then
			$Text=StringReplace($Text, 'See([ENEMY], FALSE)', 'See([ENEMY], 0)')
			$Handle=FileOpen($g_IWD2Dir&'\LOS\dlg\f#bowyer.d', 2)
			FileWrite($Handle, $Text)
			FileClose($Handle)
			$Text=StringReplace(FileRead($g_IWD2Dir&'\LOS\dlg\f#susu.d'), 'See([ENEMY], FALSE)', 'See([ENEMY], 0)')
			$Handle=FileOpen($g_IWD2Dir&'\LOS\dlg\f#susu.d', 2)
			FileWrite($Handle, $Text)
			FileClose($Handle)
		EndIf
	EndIf
; ==============      Fix keyword-test for _Test_GetModFolder-function     ============
	If StringRegExp($g_Flags[14], 'BWP|BWS') And FileExists($g_BG2Dir&'\dsotsc\setup-dsotsc.tp2') Then
		$Text=FileRead($g_BG2Dir&'\dsotsc\setup-dsotsc.tp2')
		If StringInStr($Text, Chr(0)) Then
			$Handle = FileOpen($g_BG2Dir&'\dsotsc\setup-dsotsc.tp2', 2) ; Open for overwriting
			FileWrite($Handle, StringReplace($Text, Chr(0), ''))
			FileClose($Handle)
		EndIf
	EndIf
	If StringRegExp($g_Flags[14], 'BG[1-2]EE') Then
		If FileExists($g_BG1EEDir&'\Helarine Mod') Then
			FileWrite($g_LogFile, '>Helarine Mod\JklHel\* .' & @CRLF)
			_Extract_MoveMod('Helarine Mod')
;			FileMove($g_BG1EEDir&'\JklHel\Helarine_BGEE.tp2', $g_BG1EEDir&'\JklHel\JklHel.tp2') ; now renamed after BWFixpack
		EndIf
		If FileExists($g_BG1EEDir&'\setup-bpseries.exe') Then
			If FileExists($g_BG1EEDir&'\WeiDU') And StringInStr(FileGetAttrib($g_BG1EEDir&'\WeiDU'), 'D') Then IniDelete($g_BWSIni, 'Faults', 'BPSeries')
		EndIf
		If FileExists($g_BG1EEDir&'\kitpack.tp2') Then DirCreate($g_BG1EEDir&'\kitpackbackup')
		If FileExists($g_BG1EEDir&'\kitpack.tp2') Then DirCreate($g_BG1EEDir&'\SBACKUP')
	EndIf
; ==============    create the mods folder so the tp2-test will not fail   ============
	If StringRegExp($g_Flags[14], 'BWP|BWS|BG[1-2]EE') And FileExists($g_GameDir&'\stratagems') Then DirCreate($g_GameDir&'\stratagems_external')
	If StringRegExp($g_Flags[14], 'BWP|BWS|BG2EE') And FileExists($g_GameDir&'\wheels') Then DirCreate($g_GameDir&'\stratagems_external')
	If StringRegExp($g_Flags[14], 'BWP|BWS|BG2') Then
		If FileExists($g_BG2Dir&'\setup-aurora.exe') Then DirCreate($g_BG2Dir&'\aurpatch')
		If FileExists($g_BG2Dir&'\setup-gavin_bg2.exe') Then DirCreate($g_BG2Dir&'\gavin_bg2_bgt')
		If FileExists($g_BG2Dir&'\setup-iwditempack.exe') Then DirCreate($g_BG2Dir&'\iwditemfix')
		If FileExists($g_BG2Dir&'\item_rev\item_rev.tp2') Then DirCreate($g_BG2Dir&'\item_rev_shatterfix')
		If FileExists($g_BG2Dir&'\Setup-R*deur.tp2') Then DirMove($g_BG2Dir&"\RÓdeur de l'ombre", $g_BG2Dir&"\Rôdeur de l'ombre")
		If FileExists($g_BG2Dir&'\SetupP!Bhaal.tp2') Then DirMove($g_BG2Dir&'\PrČtre de Bhaal', $g_BG2Dir&'\Prętre de Bhaal')
		If FileExists($g_BG2Dir&'\setup-astscriptpatcher.exe') Then DirCreate($g_BG2Dir&'\astScriptPatcher')
	ElseIf $g_Flags[14] = 'PST' Then
		If FileExists($g_PSTDir&'\setup-pst-drawfix.exe') Then DirCreate($g_PSTDir&'\pst-drawfix_backup')
	EndIf
; ---------------------------------------------------------------------------------------------
; Add missing archives (e.g. NSIS-extractions)
; ---------------------------------------------------------------------------------------------
	For $e = 1 To $g_CurrentPackages[0][0]; get errors of installer packages
		$ReadSection=IniReadSection($g_MODIni, $g_CurrentPackages[$e][0])
		GUICtrlSetData($g_UI_Interact[6][1], ($e * 100) / $g_CurrentPackages[0][0])
		GUICtrlSetData($g_UI_Static[6][2], _GetTR($Message, 'L2') & ' ' & _IniRead($ReadSection, 'Name', $g_CurrentPackages[$e][0]) & ' ...'); => checking
		If _IniRead($ReadSection, 'Save', 'Manual') = 'Manual' Then ContinueLoop
		$TP2Exists = _Test_GetCustomTP2($g_CurrentPackages[$e][0], '\', 1); test if packaging file is found, 1 = don't complain if BACKUP mod folder is not found
		If @error Then
			$Test = _IniRead($ReadSection, 'Test', '')
			If $Test <> '' Then; check for a file if package is not a weidu-mod
				$Test=StringSplit($Test, ':')
				If FileExists($g_GameDir&'\'&$Test[1]) Then ContinueLoop
			EndIf
			$Fault = IniRead($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], '')
			If Not StringInStr($Fault, '1') Then IniWrite($g_BWSIni, 'Faults', $g_CurrentPackages[$e][0], '1'&$Fault); save the error
		EndIf
	Next
; ---------------------------------------------------------------------------------------------
; Make sure tests fail for faulty-extractions
; ---------------------------------------------------------------------------------------------
	Local $Fault=IniReadSection($g_BWSIni, 'Faults')
	If Not @error Then
		GUICtrlSetData($g_UI_Interact[6][1], 0)
		For $f=1 to $Fault[0][0]
			If $Fault[$f][0] = 'BG1TP' Then ContinueLoop; German bg1-addons
			If $Fault[$f][0] = 'Abra' Or $Fault[$f][0] = 'BG1TotSCSound' Then ContinueLoop; Spanish bg1-addons
			If $Fault[$f][0] = 'correcfrbg1' Then ContinueLoop; French bg1-addon
			If $Fault[$f][0] = 'bg1textpack' Then ContinueLoop; Russian bg1-addon
			If $g_Flags[0] = 0 Then; the exit button was pressed
				Exit
			EndIf
			$ReadSection = IniReadSection($g_MODIni, $Fault[$f][0])
			$Mod = _IniRead($ReadSection, 'Name', $Fault[$f][0])
			_Process_SetConsoleLog(_GetTR($Message, 'L2') & ' ' & $Mod & ' ...'); => checking
			If StringInStr($Fault[$f][1], '1') Then; remove whole mod
				$TP2 = _Test_GetTP2($Fault[$f][0], '\')
				If $TP2 = '0' Then
					$Rename = IniRead($g_MODIni, $Fault[$f][0], 'REN', ''); look for some non-standard-filenames that will be renamed later
					If $Rename <> '' Then $TP2 = _Test_GetTP2($Rename, '\')
				EndIf
			EndIf
			If StringRegExp($Fault[$f][1], '2|4') Then; remove file from addon-test
				$Test=StringSplit(_IniRead($ReadSection, 'AddTest', ''), ':')
				If FileExists($g_GameDir&'\'&$Test[1]) And StringRegExp($Test[1], '\A[^.]{1,}\x2e') Then FileDelete($g_GameDir&'\'&$Test[1])
			EndIf
			If StringRegExp($Fault[$f][1], '3|5') Then; remove file from language-addon-test
				$Test=StringSplit(_IniRead($ReadSection, _GetTra($ReadSection, 'T')&'-AddTest', ''), ':')
				If FileExists($g_GameDir&'\'&$Test[1]) And StringRegExp($Test[1], '\A[^.]{1,}\x2e') <> '' Then FileDelete($g_GameDir&'\'&$Test[1])
			EndIf
		Next
	EndIf
	
	IniWrite($g_BWSIni, 'Order', 'Au3ExFix', 0); Skip this one if the Setup is rerun
	Return
EndFunc   ;==>Au3ExFix

; ---------------------------------------------------------------------------------------------
; Testing function to see if all needed files are extracted
; ---------------------------------------------------------------------------------------------
Func Au3ExTest($p_Num = 0)
	_PrintDebug('+' & @ScriptLineNumber & ' Calling Au3ExTest')
	$g_LogFile = $g_LogDir & '\EE-Debug-Extraction.log'
	Local $Message = IniReadSection($g_TRAIni, 'Ex-Au3TestExtract'), $FNum = ''
	_Process_SwitchEdit(1, 0)
	$Type=StringRegExpReplace($g_Flags[14], '(?i)BWS|BWP', 'BG2')
	GUICtrlSetData($g_UI_Interact[6][4], StringReplace(_GetSTR($Message, 'H1'), '%s', $Type)); => help text
	GUICtrlSetData($g_UI_Interact[6][1], 0)
	GUICtrlSetData($g_UI_Static[6][1], _GetTR($Message, 'L1')); => watch progress
; ---------------------------------------------------------------------------------------------
; Remove errors for core-archives that exist => TP2 have been deleted by BWS, so this was the users doing
; ---------------------------------------------------------------------------------------------
	Local $Fault=IniReadSection($g_BWSIni, 'Faults')
	If @error Then
		_Extract_EndAu3ExTest()
		Return
	EndIf
; ---------------------------------------------------------------------------------------------
; Test if errors exist
; ---------------------------------------------------------------------------------------------
	$Test=_Extract_ListMissing()
	If $Test[0][2] = 0 And $Test[0][3] = 0 Then
		_Extract_EndAu3ExTest()
		Return
	EndIf
; ---------------------------------------------------------------------------------------------
; Automatically remove all mods with errors if it's selected that way
; ---------------------------------------------------------------------------------------------
	If IniRead($g_UsrIni, 'Options', 'Logic2', 1) = 2 Then
		If $Test[0][3] = 0 Then; no essentials are missing.
			_Process_SetScrollLog(_GetTR($Message, 'L6')); => this should run propperly
			If $Test[0][0] <> 0 Then _Depend_RemoveFromCurrent($Test); remove mods/tp2-files that cannot be installed due to dependencies
			$Fault=IniReadSection($g_BWSIni, 'Faults'); remove mods with faults
			_Depend_RemoveFromCurrent($Fault, 0); remove mods that could not be loaded completely
			_Extract_EndAu3ExTest()
			Return
		Else
			_Process_SetScrollLog(_GetTR($Message, 'L8'), 1, -1); => this does not work > end
			IniWrite($g_UsrIni, 'Options', 'Logic2', 1); set interaction-mode for next BWS start
			$g_Flags[0] = 1
			_Process_Gui_Delete(6, 6, 1)
			Exit
		EndIf
	EndIf
; ---------------------------------------------------------------------------------------------
; Extract files yourself
; ---------------------------------------------------------------------------------------------
	_Process_SetScrollLog(_GetTR($Message, 'L3'), 1, -1); => mods are missing. test, provide or skip missing files?
	_Process_Question('t|p|c', _GetTR($Message, 'L4'), _GetTR($Message, 'Q1'), 3, $g_Flags[18]); => test, provide or skip missing files?
	If $g_pQuestion = 't' Then
		$CRCError=0
		$Fault=IniReadSection($g_BWSIni, 'Faults')
		For $f=1 to $Fault[0][0]
			$ReadSection=IniReadSection($g_MODIni, $Fault[$f][0])
			GUICtrlSetData($g_UI_Static[6][2], _GetTR($Message, 'L2') & ' ' & _IniRead($ReadSection, 'Name', $Fault[$f][0]) & ' ...'); => checking
			For $l=1 to StringLen($Fault[$f][1])
				$Type=StringMid($Fault[$f][1], $l, 1)
				If $Type = '1' Then
					Local $Type = 'Save'
				ElseIf $Type = '2' Or $Type = '4' Then
					Local $Type = 'AddSave'
				ElseIf $Type = '3' Or $Type = '5' Then
					Local $Type = _GetTra($ReadSection, 'T')&'-AddSave'; adjust the language-addon
				EndIf
				$Archive = _IniRead($ReadSection, $Type, 'Manual')
				If $Archive <> 'Manual' And FileExists($g_DownDir&'\'&$Archive) Then
					If _Extract_TestIntegrity($Archive) = 0 Then
						If $CRCError = 0 Then
							_Process_SetScrollLog(_GetTR($Message, 'L12')); => following are damaged
							$CRCError = 1
						EndIf
						_Process_SetScrollLog($Archive)
					EndIf
				EndIf
			Next
		Next
		If $CRCError = 0 Then _Process_SetScrollLog(_GetTR($Message, 'L13')); => all seem alright
		_Process_Question('p|c', _GetTR($Message, 'L15'), _GetTR($Message, 'Q5'), 2, $g_Flags[18]); => provide or skip missing files?
	EndIf
	If $g_pQuestion = 'p' Then
		$Extract=0
		$Fault=IniReadSection($g_BWSIni, 'Faults')
		For $f=1 to $Fault[0][0]
			$ReadSection=IniReadSection($g_MODIni, $Fault[$f][0])
			GUICtrlSetData($g_UI_Static[6][2], _IniRead($ReadSection, 'Name', $Fault[$f][0])); => checking
			_Process_SetScrollLog(_IniRead($ReadSection, 'Name', $Fault[$f][0]),0, -1); if found, save as
			For $l=1 to StringLen($Fault[$f][1])
				$Type=StringMid($Fault[$f][1], $l, 1)
				If $Type = '1' Then
					Local $Type = 'Save'
				ElseIf $Type = '2' Or $Type = '4' Then
					Local $Type = 'AddSave'
				ElseIf $Type = '3' Or $Type = '5' Then
					Local $Type = _GetTra($ReadSection, 'T')&'-AddSave'; adjust the language-addon
				EndIf
				$Archive = _IniRead($ReadSection, $Type, 'Manual')
				_Process_Question('d|e|o|a', _GetTR($Message, 'L5'), _GetTR($Message, 'Q2'), 4); => load or skip mod or skip all
				If $g_pQuestion = 'o' Then ContinueLoop(2); skip one mod
				If $g_pQuestion = 'a' Then ExitLoop(2); skip all mods
				If $g_pQuestion = 'd' Then
					$URL= _IniRead($ReadSection, StringReplace($Type, 'Save', 'Down'), '')
					If $URL <> '' And $URL <> 'Manual' Then ShellExecute($URL); start browser
				EndIf
				If $g_pQuestion = 'e' And $Archive <> 'Manual' And FileExists($g_DownDir&'\'&$Archive) Then ShellExecute($g_DownDir&'\'&$Archive); start zip
				$Extract+=1
			Next
		Next
		If $Extract > 0 Then _Process_Question('c', _GetTR($Message, 'L14'), _GetTR($Message, 'Q4')); =>Enter continue after extractions are finished
		$Test=_Extract_ListMissing()
		If $Test[0][2] = 0 And $Test[0][3] = 0 Then
			_Process_SetScrollLog(_GetTR($Message, 'L11'), 1, -1); => missing found, continue in 5 seconds
			Sleep(5000)
			_Extract_EndAu3ExTest()
			Return
		EndIf
	EndIf
; ---------------------------------------------------------------------------------------------
; No essential files are missing: Start to solve problems
; ---------------------------------------------------------------------------------------------
	If $Test[0][3] = 0 Then
		_Process_SetScrollLog('|'&_GetTR($Message, 'L6')); => this should run propperly
		_Process_SetScrollLog(_GetTR($Message, 'L7'), 1, -1); => please check the missing ones
		_Process_Question('y|n|c', _GetTR($Message, 'L9'), _GetTR($Message, 'Q3'), 3); => remove the missing mods?
		If $g_pQuestion = 'y' Then; user want's delete the (possible) broken extracted archives.
			$Fault=IniReadSection($g_BWSIni, 'Faults')
			If @error Then
				_Extract_EndAu3ExTest()
				Return
			EndIf
			If $Test[0][0] <> 0 Then _Depend_RemoveFromCurrent($Test); remove mods/tp2-files that cannot be installed due to dependencies
			_Depend_RemoveFromCurrent($Fault, 0)
		ElseIf $g_pQuestion = 'c' Then; exit
			Exit
		EndIf
		_Extract_EndAu3ExTest()
	Else
		_Process_SetScrollLog(_GetTR($Message, 'L8'), 1, -1); => this does not work > end
		$g_Flags[0] = 1
		_Process_Gui_Delete(6, 6, 1)
		Exit
	EndIf
EndFunc   ;==>Au3ExTest

; ---------------------------------------------------------------------------------------------
; [ScS] Close all visible CMD-windows
; ---------------------------------------------------------------------------------------------
Func _CloseNSISWeiDUs()
	$Array=_FileSearch($g_GameDir & '\NSIS', 'Setup-*.exe')
	For $a=1 To $Array[0]
		If ProcessExists($Array[$a]) Then
			For $k=1 to 5
				ProcessClose($Array[$a])
				Sleep(50)
			Next
		EndIf
	Next
EndFunc   ;==>_CloseNSISWeiDUs

; ---------------------------------------------------------------------------------------------
; Suppress further Au3ExTest-runs
; ---------------------------------------------------------------------------------------------
Func _Extract_EndAu3ExTest()
	_Process_SwitchEdit(0, 0)
	IniDelete($g_BWSIni, 'Faults')
	IniWrite($g_BWSIni, 'Order', 'Au3ExTest', 0); Skip this one if the Setup is rerun
; ---------------------------------------------------------------------------------------------
; delete old files -- if extraction was done and install starts now, the patching has to be done
; ---------------------------------------------------------------------------------------------
	If StringRegExp($g_Flags[14], 'BWP|BWS') Then
		FileDelete ($g_BG2Dir & '\BWP_Fixpack.installed')
		FileDelete ($g_BG2Dir & '\BWP_Textpack.installed')
		FileDelete ($g_BG2Dir & '\BWP_Smoothpack.installed')
	EndIf
	If IniRead($g_UsrIni, 'Options', 'Logic2', 1) = 3 Then
		_Process_SetConsoleLog(IniRead($g_TRAIni, 'Ex-Au3TestExtract', 'L10', ''))
		_Process_Pause(); pause after extraction
	EndIf
EndFunc    ;==>_Extract_EndAu3ExTest

; ---------------------------------------------------------------------------------------------
; Functions that start with a "_" are not available from the [Order]-section in the ini-file.
; Extract an archive-file
; ---------------------------------------------------------------------------------------------
Func _Extract_7z($p_File, $p_Dir, $p_String = ''); $a=archive; $b=outputdir; $c=setup
	Local $Message = IniReadSection($g_TRAIni, 'Ex-7z')
	If $p_String = '' Then $p_String = $p_File
	;_PrintDebug('+' & @ScriptLineNumber & ' Calling _Extract_7z')
	Local $7za = $g_ProgDir & '\Tools\7z.exe', $Found = 0
	If Not FileExists($7za) Then
		_Misc_MsgGUI(4, _GetTR($Message, 'T1'), _GetTR($Message, 'L1') & ' ' & $g_ProgDir & '.'); => extracting
		Exit
	EndIf
	_Process_Run('"' & _StringVerifyAscII($7za) & '" x "' & _StringVerifyAscII($p_File) & '" -aoa -o"' & _StringVerifyAscII($p_Dir) & '"', '7z.exe')
	$Summary = StringSplit(StringStripCR($g_ConsoleOutput), @LF)
	For $s=$Summary[0] to 1 Step -1
		If StringInStr($Summary[$s], 'Processing archive') Then ExitLoop
		If StringInStr($Summary[$s], 'Everything is Ok') Then $Found = 1
	Next
	If $Found = 1 Then
		_Process_SetConsoleLog(@CRLF & $p_String & ' ' & _GetTR($Message, 'L2') & @CRLF); => success
		Sleep(1000)
		Return '1'
	Else; something went wrong
		ConsoleWrite('---------------------------' & @CRLF)
		For $s=1 to $Summary[0]
			ConsoleWrite('['&$s&'] '&  $Summary[$s] & @CRLF)
		Next
		ConsoleWrite('---------------------------' & @CRLF)
		_Process_SetConsoleLog(_GetTR($Message, 'E1') & @CRLF & '"' & $7za & '" x "' & $p_File & '" -aoa -o"' & $p_Dir & '"' & @CRLF & _GetTR($Message, 'E2') & @CRLF); => failed due to unknown reasons
		ConsoleWrite(_GetTR($Message, 'E1') & @CRLF & '"' & $7za & '" x "' & $p_File & '" -aoa -o"' & $p_Dir & '"' & @CRLF & _GetTR($Message, 'E2') & @CRLF); => failed due to unknown reasons
		GUICtrlSetColor($g_UI_Interact[6][3], 0xff0000); paint the item red
		Sleep(1000)
		GUICtrlSetColor($g_UI_Interact[6][3], 0x000000); paint the item black again
		Return '0'
	EndIf
EndFunc   ;==>_Extract_7z

; ---------------------------------------------------------------------------------------------
; Extract $p_Save-file from $p_Mod if it exists to $p_Folder
; ---------------------------------------------------------------------------------------------
Func _Extract_CaseRemove($p_Mod, $p_Folder, $p_Save='Save')
	$ReadSection = IniReadSection($g_MODIni, $p_Mod)
	If $p_Save = '-' Then $p_Save = _GetTra($ReadSection, 'T') & '-AddSave'
	$Save = _IniRead($ReadSection, $p_Save, '')
	If $Save = '' Then Return; don't extract the complete download-folder
	$Mod = _IniRead($ReadSection, 'Name', '')
	If FileExists($g_DownDir&'\'&$Save) Then
		$Success = _Extract_7z($g_DownDir&'\'&$Save, $p_Folder, $Mod)
		If $Success <> 1 Then
			IniWrite($g_BWSIni, 'Faults', $p_Mod, 1); save the error
		Else
			IniDelete($g_BWSIni, 'Faults', $p_Mod); delete the error
		EndIf
	EndIf
EndFunc    ;==>_Extract_CaseRemove

; ---------------------------------------------------------------------------------------------
; Extract mod to to BG2-folder
; ---------------------------------------------------------------------------------------------
Func _Extract_CheckMod($p_File, $p_Dir, $p_Setup); $a=file, $b=dir, $c=mod
	;_PrintDebug('+' & @ScriptLineNumber & ' Calling _Extract_CheckMod')
	Local $Message = IniReadSection($g_TRAIni, 'Ex-CheckMod')
	If FileExists($p_Dir & '\' & $p_File) Then
		If StringRight($p_File, 3) = 'exe' Then; test if we got a nsis
			$FileBody = FileRead($p_Dir & '\' & $p_File, 1024 * 50)
			If StringInStr($FileBody, 'Nullsoft') Then
				FileCopy($p_Dir & '\' & $p_File, ($g_GameDir & '\' & $p_File)); put a copy into bg2 so the nsis-part can work properly
				_Process_SetConsoleLog(_GetTR($Message, 'L3')); => NSIS will be extracted later
				Return '0' ; nothing to do here
			EndIf
			If StringInStr($FileBody, 'InnoSetup') Then
				RunWait($p_Dir & '\' & $p_File & ' /DIR="' & $g_GameDir & '" /VERYSILENT')
				_Process_SetConsoleLog(_GetTR($Message, 'L4')); => execute silent inno
				Return '1'; nothing to do here
			EndIf
		ElseIf StringRight($p_File, 3) = 'tp2' Then; overwrite TP2-files
			$TP2=_Test_GetTP2(StringRegExpReplace($p_File, '(?i)-{0,1}(setup)-{0,1}|\x2etp2\z', ''))
			Local $Text='L2', $Success=0
			If $TP2 <> '0' Then
				$Success=FileCopy($p_Dir&'\'&$p_File, $TP2, 1)
				If $Success Then $Text='L1'
			EndIf
			_Process_SetConsoleLog($p_File& ' ' & IniRead($g_TRAIni, 'BA-FileAction', $Text, ''))
			Return $Success
		EndIf
		$iSize = Round(FileGetSize($p_Dir & '\' & $p_File) / (1024 * 1024), 1)
		If $iSize = '0.0' Then $iSize = '0.1'
		GUICtrlSetData($g_UI_Static[6][2], _GetTR($Message, 'L1') & ' ' & $p_Setup & ' (' & $iSize & ' MB)'); => extracting
		_Process_SetConsoleLog(_GetTR($Message, 'L1') & ' ' & $p_File & ' (' & $iSize & ' MB)' & @CRLF); => extracting
		$Success = _Extract_7z($p_Dir & '\' & $p_File, $g_GameDir, $p_File); call another function
		Return $Success
		;_CleanupExtract($g_CurrentPackages[$p_Dir][0]);~ fix some little glitches
		;_WeiduUpdate($g_CurrentPackages[$p_Dir][0]);~ updates weidu to prevent a second extraction if setup isn't packed into the archive.
	Else
		_Process_SetConsoleLog(_GetTR($Message, 'L2') & @CRLF); => could not be found
		GUICtrlSetColor($g_UI_Interact[6][3], 0xff0000); paint the item red
		Sleep(1000)
		GUICtrlSetColor($g_UI_Interact[6][3], 0x000000); paint the item black again
		Return '0'
	EndIf
EndFunc   ;==>_Extract_CheckMod

; ---------------------------------------------------------------------------------------------
; Install all NullSoft Installers that are located in a directory
; ---------------------------------------------------------------------------------------------
Func _Extract_InstallNSIS($p_Dir); $p_Dir=dir
	Local $Message = IniReadSection($g_TRAIni, 'Ex-InstallNSIS')
	$Found=0
	$Files=_FileSearch($p_Dir, '*.exe')
	For $f=1 to $Files[0]
		If StringInStr($Files[$f], 'Setup-') Then ContinueLoop; leave out weidu
		$FileBody = FileRead($p_Dir & '\' & $Files[$f], 1024 * 50)
		If StringInStr($FileBody, 'Nullsoft') Then
			If $Found = 0 Then
				If IniRead($g_UsrIni, 'Options', 'Logic2', 1) = 2 Then; don't halt NSIS-message if it's an over-night-installation (Logic2=2)
					_Misc_MsgGUI(3, _GetTR($Message, 'T1'), _GetTR($Message, 'L1'), 1, _GetTR($Message, 'B1'), '', '', 5); => starting silent install + notes
				Else
					_Misc_MsgGUI(3, _GetTR($Message, 'T1'), _GetTR($Message, 'L1'), 1, _GetTR($Message, 'B1')); => starting silent install + notes
				EndIf
				$Found = 1
			EndIf
			GUISetState(@SW_MINIMIZE, $g_UI[0])
			FileWrite($g_LogFile, '>'& $Files[$f] & @CRLF)
			ShellExecute($p_Dir & '\' & $Files[$f], ' /S /D='&$g_GameDir & '\NSIS'); run will not work with setups and windows7+UAC
			While ProcessExists($Files[$f])
				ControlSend('[Class:#32770]', '', '', '{Enter}')
				ControlSend('[Class:#32770]', '', 'Button1', '{Space}')
				ControlSend('[Class:#32770]', '', 'Button1', '{Enter}')
				_CloseNSISWeiDUs(); will not work on windows7+UAC since setups are running as administrator and thus actions on those windows are forbidden
				Sleep(100)
			WEnd
			If StringInStr($Files[$f], 'CespyAudio') Then
				$Test=WinWaitActive('[REGEXPTITLE:c2audioREADME]', '', 60)
				WinClose('[REGEXPTITLE:c2audioREADME]')
			EndIf
			While 1; delete the setup after executing it
				$Success = FileDelete($p_Dir&'\'&$Files[$f])
				If $Success = 1 Then ExitLoop
			WEnd
		EndIf
	Next
	_CloseNSISWeiDUs()
	Return $Found
EndFunc   ;==>_Extract_InstallNSIS

; ---------------------------------------------------------------------------------------------
; List the archives that had problems
; ---------------------------------------------------------------------------------------------
Func _Extract_ListMissing()
	Local $Message = IniReadSection($g_TRAIni, 'Ex-ListMissing')
	Local $mNum=0, $oNum=0, $fNum=0, $Dependent
	Local $Fault=IniReadSection($g_BWSIni, 'Faults')
	If @error Then
		_Extract_EndAu3ExTest()
		Local $Dependent[1][4] = [[0, '', 0, 0]]
		Return $Dependent
	EndIf
	_Process_SetScrollLog(_GetTR($Message, 'L1')); => The extraction of the following mod(s) failed:
	For $f=1 to $Fault[0][0]
		$ReadSection=IniReadSection($g_MODIni, $Fault[$f][0])
		$Mod = _IniRead($ReadSection, 'Name', $Fault[$f][0])
		If StringInStr($Fault[$f][1], '1') Then; check for TP2
			If _Test_GetCustomTP2($Fault[$f][0], '\', 1) <> '0' Then; 1 = don't complain if BACKUP mod folder is not found
				$Fault[$f][1]=StringRegExpReplace($Fault[$f][1], '1', '')
			ElseIf _IniRead($ReadSection, 'Test', '') <> '' Then; check for a file if package is not a weidu-mod
				If _Extract_TestFile(_IniRead($ReadSection, 'Test', '')) = 1 Then $Fault[$f][1]=StringRegExpReplace($Fault[$f][1], '1', '')
			EndIf
		EndIf
		If StringRegExp($Fault[$f][1], '2|4') Then; check for additional file
			If _Extract_TestFile(_IniRead($ReadSection, 'AddTest', '')) = 1 Then $Fault[$f][1]=StringRegExpReplace($Fault[$f][1], '2|4', '')
		EndIf
		If StringRegExp($Fault[$f][1], '3|5') Then; check for additional language-file
			If _Extract_TestFile(_IniRead($ReadSection, _GetTra($ReadSection, 'T')&'-AddTest', '')) = 1 Then $Fault[$f][1]=StringRegExpReplace($Fault[$f][1], '3|5', '')
		EndIf
		If $g_BG1Dir <> '-' Then; check for BG1 fixes
			If $Fault[$f][0] = 'BG1TotSCSound' And _Test_CheckTotSCFiles_BG1() = 1 Then $Fault[$f][1]=''; extracted spanish bg1-sounds (bifs)
			If $Fault[$f][0] = 'BG1TP' And FileExists($g_BG1Dir&'\setup-bg1tp.exe') Then $Fault[$f][1]=''; extracted German Textpatch
			If $Fault[$f][0] = 'Abra' And FileExists($g_BG1Dir&'\setup-abra.exe') Then $Fault[$f][1]=''; extracted Spanish Textpatch
			If $Fault[$f][0] = 'correcfrbg1' And FileExists($g_BG1Dir&'\setup-correcfrbg1.exe') Then $Fault[$f][1]=''; extracted French Textpatch
			If $Fault[$f][0] = 'bg1textpack' And FileExists($g_BG1Dir&'\setup-bg1textpack.exe') Then $Fault[$f][1]=''; extracted Russian Textpatch
		EndIf
		If $Fault[$f][1] = '' Then
			IniDelete($g_BWSIni, 'Faults', $Fault[$f][0]); remove the error
			ContinueLoop
		Else
			IniWrite($g_BWSIni, 'Faults', $Fault[$f][0], $Fault[$f][1]); remove the error
		EndIf
		Local $Mark = ''
		If StringRegExp($g_fLock, '(?i)(\A|\x2c)'&$Fault[$f][0]&'(\z|\x2c)') Then
			$fNum=1
			$Mark&=' ' & Chr(0xB9); if mod is fixed, mark as missing essential
		EndIf
		For $l=1 to StringLen($Fault[$f][1])
			$Type=StringMid($Fault[$f][1], $l, 1)
			If $Type = '1' Then
				Local $Type = 'Save', $Hint = _GetTR($Message, 'L2'); => main
			ElseIf $Type = '2' Then
				Local $Type = 'AddSave', $Hint = _GetTR($Message, 'L3'); => additional
			ElseIf $Type = '3' Then
				Local $Type = _GetTra($ReadSection, 'T') & '-AddSave', $Hint = _GetTR($Message, 'L4'); => translation
			ElseIf $Type = '4' Then
				Local $mNum = 1, $Type = 'AddSave', $Hint = _GetTR($Message, 'L3'); => additional
				$Mark&=' ' & Chr(0xB2)
			ElseIf $Type = '5' Then
				Local $mNum = 1, $Type = _GetTra($ReadSection, 'T') & '-AddSave', $Hint = _GetTR($Message, 'L4'); => translation
				$Mark&=' ' & Chr(0xB2)
			EndIf
			If $Fault[$f][0] = 'BG1TP' Or $Fault[$f][0] = 'correcfrbg1' Or $Fault[$f][0] = 'Abra' Or $Fault[$f][0] = 'BG1TotSCSound' Or $Fault[$f][0] = 'bg1textpack' Then
				$oNum=1
				$Mark&=' ' & Chr(0xB3)
			EndIf
			_Process_SetScrollLog(_IniRead($ReadSection, 'Name', $Fault[$f][0])&': '&$Hint&' ('&_IniRead($ReadSection, $Type, '')&')'&$Mark); tell what's missing
		Next
	Next
	$Dependent=_Depend_GetUnsolved('', ''); $Dependent[0][unsolved, output, missing + unsolved]
	If $Dependent[0][0] <> 0 Then
		_Process_SetScrollLog(_GetTR($g_UI_Message, '6-L6')); => mods cannot be installed due to dependencies
		_Process_SetScrollLog($Dependent[0][1])
	EndIf
	Local $Fault=IniReadSection($g_BWSIni, 'Faults'); Another test - search for tp2-files may have been successful
	If @error Then
		_Extract_EndAu3ExTest()
		Local $Dependent[1][4] = [[0, '', 0, 0]]
		Return $Dependent
	EndIf
	If $FNum = 1 Then
		_Process_SetScrollLog(_GetTR($Message, 'L5')); => cannot continue without essential mod
		$Dependent[0][3] = 1
	EndIf
	If $mNum = 1 Then _Process_SetScrollLog(_GetTR($Message, 'L6')); => addons extracted while main-file not
	If $oNum = 1 Then _Process_SetScrollLog(_GetTR($Message, 'L7')); => extract to bg1-folder
	_Process_SetScrollLog('')
	Return $Dependent
EndFunc    ;==>_Extract_ListMissing

; ---------------------------------------------------------------------------------------------
; extract BG1TP and sounds to BG1 dir if the archive exists in the download-dir and it's not already installed
; ---------------------------------------------------------------------------------------------
Func _Extract_MissingBG1()
	If _Test_CheckTotSCFiles_BG1() = 0 Then; extract spanish bg1-sounds (bifs)
		_Extract_CaseRemove('BG1TotSCSound', $g_BG1Dir&'\Data')
		If _Test_CheckTotSCFiles_BG1() = 1 Then IniDelete($g_BWSIni, 'Faults', 'BG1TotSCSound')
	EndIf
	If _Test_CheckBG1TP() <> 1 Then; this one is the only (german) weidu that is extracted into the bg1-folder
		_Extract_CaseRemove('BG1TP', $g_BG1Dir)
		If FileExists($g_BG1Dir&'\setup-bg1tp.tp2') Then IniDelete($g_BWSIni, 'Faults', 'BG1TP')
	EndIf
	If Not StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~setup-abra.tp2') And $g_MLang[1] = 'SP' Then; this one is the only (Spanish) weidu that is extracted into the bg1-folder
		_Extract_CaseRemove('Abra', $g_BG1Dir)
		If StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~setup-abra.tp2') Then IniDelete($g_BWSIni, 'Faults', 'Abra')
	EndIf
	If Not StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~correcfrbg1/correcfrbg1.tp2') And $g_MLang[1] = 'FR' Then; this one is the only (French) weidu that is extracted into the bg1-folder
		_Extract_CaseRemove('correcfrbg1', $g_BG1Dir)
		If StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~correcfrbg1/correcfrbg1.tp2') Then IniDelete($g_BWSIni, 'Faults', 'correcfrbg1')
	EndIf
	If Not StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~bg1textpack/setup-bg1textpack.tp2') And $g_MLang[1] = 'RU' Then; this one is the only (Russian) weidu that is extracted into the bg1-folder
		_Extract_CaseRemove('bg1textpack', $g_BG1Dir)
		If StringInStr(FileRead($g_BG1Dir&'\Weidu.log'), @LF&'~bg1textpack/setup-bg1textpack.tp2') Then IniDelete($g_BWSIni, 'Faults', 'bg1textpack')
	EndIf
EndFunc    ;==>_Extract_MissingBG1

; ---------------------------------------------------------------------------------------------
; Move content of a subfolder to BG2-folder
; ---------------------------------------------------------------------------------------------
Func _Extract_MoveMod($p_Dir)
	Local $Success=0
	$Files=_FileSearch($g_GameDir & '\' & $p_Dir, '*')
	For $f=1 to $Files[0]
		If StringInStr(FileGetAttrib($g_GameDir & '\' & $p_Dir & '\' & $Files[$f]), "D") Then
			$Success = DirMove($g_GameDir & '\' & $p_Dir & '\' & $Files[$f], $g_GameDir, 1)
		Else
			$Success = FileMove($g_GameDir & '\' & $p_Dir & '\' & $Files[$f], $g_GameDir & '\', 1)
		EndIf
		If $Success = 0 Then Return 0
	Next
	$Success = DirRemove($g_GameDir & '\' & $p_Dir, 1)
	Return $Success
EndFunc   ;==>_Extract_MoveMod

Func _Extract_MoveModEx($p_Dir)
	Local $Success=0
	$Files=_FileSearch($g_GameDir & '\' & $p_Dir, '*')
	For $f=1 to $Files[0]
		If StringInStr(FileGetAttrib($g_GameDir & '\' & $p_Dir & '\' & $Files[$f]), "D") Then
			$Success = DirCopy($g_GameDir & '\' & $p_Dir & '\' & $Files[$f], $g_GameDir & '\' & $Files[$f], 1)
		Else
			$Success = FileCopy($g_GameDir & '\' & $p_Dir & '\' & $Files[$f], $g_GameDir & '\' & $Files[$f], 1)
		EndIf
		If $Success = 0 Then Return 0
	Next
	; if we move al files from $g_GameDir\randomiser\randomiser\* (this folder contains randomiser.tp2) to one level up, $p_Dir will still be named "randomiser"
	; so we cannot remove any files inside "$g_GameDir\$p_Dir" at this point because $g_GameDir\randomiser contains actual mod files and randomiser.tp2
	$FilesAfterMove=_FileSearch($g_GameDir & '\' & $p_Dir, '*')
	If $FilesAfterMove = 0 Then
		$Success = DirRemove($g_GameDir & '\' & $p_Dir, 1)
	Else
		$Success = 1
	EndIf
	Return $Success
EndFunc   ;==>_Extract_MoveModEx

; ---------------------------------------------------------------------------------------------
; Little filetests for some content of addtional archives
; ---------------------------------------------------------------------------------------------
Func _Extract_TestFile($p_String)
	If $p_String = '' Then Return 1
	$p_String = StringSplit($p_String, ':')
	If Not FileExists($g_GameDir & '\' & $p_String[1]) Then Return 0
	If FileGetSize($g_GameDir & '\' & $p_String[1]) And $p_String[2] = '-' Then Return 1
	If FileGetSize($g_GameDir & '\' & $p_String[1]) <> $p_String[2] Then Return 0
	Return 1
EndFunc    ;==>_Extract_TestFile

; ---------------------------------------------------------------------------------------------
; Check if 7z can list the mods content
; ---------------------------------------------------------------------------------------------
Func _Extract_TestIntegrity($p_File)
	Local $7za = $g_ProgDir & '\Tools\7z.exe'
	$PID=Run($7za&' t "'&$g_DownDir&'\'&$p_File&'"', $g_DownDir, @SW_HIDE, 8)
	ProcessWaitClose($PID)
	$Output=StdoutRead($PID)
	If StringInStr($Output, 'Everything is Ok') Then Return 1
	Return 0
EndFunc    ;==>_Extract_TestIntegrity

; #FUNCTION# ========================================================================================================================
; Name...........: _FileListToArray
; Description ...: Lists files and\or folders in a specified path (Similar to using Dir with the /B Switch)
; Syntax.........: _FileListToArray($sPath[, $sFilter = "*"[, $iFlag = 0]])
; Parameters ....: $sPath   - Path to generate filelist for.
;                 $sFilter - Optional the filter to use, default is *. (Multiple filter groups such as "All "*.png|*.jpg|*.bmp") Search the Autoit3 helpfile for the word "WildCards" For details.
;                 $iFlag   - Optional: specifies whether to return files folders or both Or Full Path (add the flags together for multiple operations):
;                 |$iFlag = 0 (Default) Return both files and folders
;                 |$iFlag = 1 Return files only
;                 |$iFlag = 2 Return Folders only
;                 |$iFlag = 4 Search subdirectory
;                 |$iFlag = 8 Return Full Path
; Return values .: @Error - 1 = Path not found or invalid
;                 |2 = Invalid $sFilter
;                 |3 = Invalid $iFlag
;                 |4 = No File(s) Found
; Author ........: SolidSnake <MetalGX91 at GMail dot com>
; Modified.......:
; Remarks .......: The array returned is one-dimensional and is made up as follows:
;                               $array[0] = Number of Files\Folders returned
;                               $array[1] = 1st File\Folder
;                               $array[2] = 2nd File\Folder
;                               $array[3] = 3rd File\Folder
;                               $array[n] = nth File\Folder
; Related .......:
; Link ..........:
; Example .......: Yes
; Note ..........: Special Thanks to Helge and Layer for help with the $iFlag update speed optimization by code65536, pdaughe
;                 Update By DXRW4E
; ===================================================================================================================================
Func _FileListToArrayEx($sPath, $sFilter = "*", $iFlag = 0)
    Local $hSearch, $sFile, $sFileList, $iFlags = StringReplace(BitAND($iFlag, 1) + BitAND($iFlag, 2), "3", "0"), $sSDir = BitAND($iFlag, 4), $FPath = "", $sDelim = "|", $sSDirFTMP = $sFilter
    $sPath = StringRegExpReplace($sPath, "[\\/]+\z", "") & "\" ; ensure single trailing backslash
    If Not FileExists($sPath) Then Return SetError(1, 1, "")
    If BitAND($iFlag, 8) Then $FPath = $sPath
    If StringRegExp($sFilter, "[\\/:><]|(?s)\A\s*\z") Then Return SetError(2, 2, "")
    If Not ($iFlags = 0 Or $iFlags = 1 Or $iFlags = 2 Or $sSDir = 4 Or $FPath <> "") Then Return SetError(3, 3, "")
    $hSearch = FileFindFirstFile($sPath & "*")
    If @error Then Return SetError(4, 4, "")
    Local $hWSearch = $hSearch, $hWSTMP = $hSearch, $SearchWD, $sSDirF[3] = [0, StringReplace($sSDirFTMP, "*", ""), "(?i)(" & StringRegExpReplace(StringRegExpReplace(StringRegExpReplace(StringRegExpReplace(StringRegExpReplace(StringRegExpReplace("|" & $sSDirFTMP & "|", '\|\h*\|[\|\h]*', "\|"), '[\^\$\(\)\+\[\]\{\}\,\.\=]', "\\$0"), "\|([^\*])", "\|^$1"), "([^\*])\|", "$1\$\|"), '\*', ".*"), '^\||\|$', "") & ")"]
    While 1
        $sFile = FileFindNextFile($hWSearch)
        If @error Then
            If $hWSearch = $hSearch Then ExitLoop
            FileClose($hWSearch)
            $hWSearch -= 1
            $SearchWD = StringLeft($SearchWD, StringInStr(StringTrimRight($SearchWD, 1), "\", 1, -1))
        ElseIf $sSDir Then
            $sSDirF[0] = @extended
            If ($iFlags + $sSDirF[0] <> 2) Then
                If $sSDirF[1] Then
                    If StringRegExp($sFile, $sSDirF[2]) Then $sFileList &= $sDelim & $FPath & $SearchWD & $sFile
                Else
                    $sFileList &= $sDelim & $FPath & $SearchWD & $sFile
                EndIf
            EndIf
            If Not $sSDirF[0] Then ContinueLoop
            $hWSTMP = FileFindFirstFile($sPath & $SearchWD & $sFile & "\*")
            If $hWSTMP = -1 Then ContinueLoop
            $hWSearch = $hWSTMP
            $SearchWD &= $sFile & "\"
        Else
            If ($iFlags + @extended = 2) Or StringRegExp($sFile, $sSDirF[2]) = 0 Then ContinueLoop
            $sFileList &= $sDelim & $FPath & $sFile
        EndIf
    WEnd
    FileClose($hSearch)
    If Not $sFileList Then Return SetError(4, 4, "")
    Return StringSplit(StringTrimLeft($sFileList, 1), "|")
EndFunc    ;==>_FileListToArrayEx

; ---------------------------------------------------------------------------------------------
; If there are files in a directory in the BWS folder named OverwriteFiles\<current game type>\
; then copy those files to the current game folder, overwriting any existing files there
; ---------------------------------------------------------------------------------------------
Func _Extract_OverwriteFiles()
	If $g_Flags[14] = 'BWS' Then
		Local $gameType = 'BWP'
	Else
		Local $gameType = $g_Flags[14]
	EndIf
	Local $overwriteDir = $g_BaseDir&'\'&'OverwriteFiles'&'\'&$gameType
    Local $Success = 0
    Local $ProcID = Run(@ComSpec & ' /c xcopy /H /Y /C /Q /R /E "' & $overwriteDir & '" "' & $g_GameDir & '"', "", @SW_HIDE)
    Do
        Sleep(100)
    Until NOT ProcessExists($ProcID)
EndFunc    ;==>_Extract_OverwriteFiles
