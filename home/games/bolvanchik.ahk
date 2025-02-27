#NoEnv

if !A_IsAdmin {
  Run *RunAs "%A_ScriptFullPath%"
  exitapp
}

WinGet, lotro_window, PID, ahk_exe lotroclient64.exe



/* 
no afk script
*/ 


Loop, 
  {

  ;  MyVar := 1 * 60000 ; x- minutes and times 60000 gives the time in milliseconds.
  ;  Sleep MyVar
    
    Sleep, 60000

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,1,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
  
  /* 
    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,s,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
*/ 


  }
  
  Return

CloseGui:
  Gui, Destroy
  ExitApp
  return
