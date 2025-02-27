#NoEnv

if !A_IsAdmin {
  Run *RunAs "%A_ScriptFullPath%"
  exitapp
}

WinGet, lotro_window, PID, ahk_exe lotroclient64.exe


/* 
b1 - Rend
b2 - Swift Blade
b3 - Blade Wall
b4 - Battle Frenzy
b5 - Raging Blade
b6 - Exchange of Blows
b7 - Fear Nothing
b8 - Born for Commbat
*/ 


Loop, 
  {

    Sleep, 1500

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,1,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
  
    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,2,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%

    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,3,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
  


    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,6,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%


    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,7,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%


    Random, ran, 800, 900
    Sleep, %ran%  


    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,4,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
  
    Random, ran, 800, 1000
    Sleep, %ran%

    ControlSend,,5,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%
  




    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,1,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%
  
    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,2,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%

    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,3,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%



    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,1,ahk_pid %lotro_window%
    Random, ran, 400, 700
    SetKeyDelay, %ran%

    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,2,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%
  
    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,3,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%


    
    Random, ran, 800, 900
    Sleep, %ran%

    ControlFocus,,ahk_pid %lotro_window%
    ControlSend,,8,ahk_pid %lotro_window%
    Random, ran, 400, 600
    SetKeyDelay, %ran%


  }
  
  Return

CloseGui:
  Gui, Destroy
  ExitApp
  return
