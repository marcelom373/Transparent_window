#Persistent
SetBatchLines, -1

; --- MAGIA MULTI-MONITOR Y DPI ---
; Obliga a Windows a dar las coordenadas de píxeles reales en cualquier monitor (Per-Monitor DPI Aware)
Try DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
Catch
    DllCall("user32.dll\SetProcessDPIAware")

; --- MATRICES MULTIVENTANA ---
Global ActiveBlurs := {}
Global GuiNames := {}
Global LastPos := {}
Global DisabledApps := {}

; --- TU LISTA VIP DE APLICACIONES ---
Global AllowedApps := "chrome.exe,msedge.exe"

SetTimer, AutoAppCheck, 500
SetTimer, FollowWindows, 10

; --- ATAJO DE TECLADO MANUAL (Ctrl + Alt + Clic Derecho) ---
^!RButton::
    WinGet, active_id, ID, A
    
    if (ActiveBlurs.HasKey(active_id))
    {
        WinGet, procName, ProcessName, ahk_id %active_id%
        if procName in %AllowedApps%
            DisabledApps[active_id] := true
            
        DeactivateBlur(active_id)
    }
    else
    {
        DisabledApps.Delete(active_id) 
        ActivateBlur(active_id)
    }
return

; --- VIGILANTE AUTOMÁTICO ---
AutoAppCheck:
    WinGet, active_id, ID, A
    WinGet, procName, ProcessName, ahk_id %active_id%
    
    if procName in %AllowedApps%
    {
        WinGetTitle, title, ahk_id %active_id%
        if (title != "" && !ActiveBlurs.HasKey(active_id) && !DisabledApps.HasKey(active_id))
        {
            ActivateBlur(active_id)
        }
    }
return

; --- BUCLE SEGUIDOR MULTI-MONITOR ---
FollowWindows:
    For target, blurGui in ActiveBlurs
    {
        if !WinExist("ahk_id " target)
        {
            DeactivateBlur(target)
            continue
        }
        
        WinGet, isMinMax, MinMax, ahk_id %target%
        GuiName := GuiNames[target]
        
        if (isMinMax = -1)
        {
            Gui, %GuiName%: Hide
            LastPos[target] := "" 
            continue
        }
        
        GetTrueWindowPos(target, tX, tY, tW, tH)
        
        ; --- SOLUCIÓN A LA BARRA DE TAREAS ---
        ; Si está maximizada, restamos 1 píxel para evitar el modo "Pantalla Completa Exclusiva" de Windows
        if (isMinMax = 1)
        {
            tH := tH - 1
        }
        
        pos := LastPos[target]
        
        if (!IsObject(pos) || tX != pos.X || tY != pos.Y || tW != pos.W || tH != pos.H)
        {
            Gui, %GuiName%: Show, NA
            WinMove, ahk_id %blurGui%,, %tX%, %tY%, %tW%, %tH%
            LastPos[target] := {X: tX, Y: tY, W: tW, H: tH}
        }
        
        hwndBelow := DllCall("GetWindow", "Ptr", target, "UInt", 2, "Ptr")
        
        if (hwndBelow != blurGui)
        {
            DllCall("user32.dll\SetWindowPos", "Ptr", blurGui, "Ptr", target, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
        }
    }
return

; --- FUNCIONES PRINCIPALES ---
ActivateBlur(target) {
    if (ActiveBlurs.HasKey(target))
        return
        
    GuiName := "Blur_" . target
    Gui, %GuiName%: New, +HwndhBlurBg -Caption +ToolWindow -DPIScale +E0x08000000
    Gui, %GuiName%: Color, 111111 
    
    EnableBlurBehind(hBlurBg)
    
    GetTrueWindowPos(target, tX, tY, tW, tH)
    
    WinGet, isMinMax, MinMax, ahk_id %target%
    if (isMinMax = 1)
        tH := tH - 1
        
    LastPos[target] := {X: tX, Y: tY, W: tW, H: tH}
    
    Gui, %GuiName%: Show, x%tX% y%tY% w%tW% h%tH% NA
    WinSet, Transparent, 220, ahk_id %target%
    
    DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", target, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    
    ActiveBlurs[target] := hBlurBg
    GuiNames[target] := GuiName
}

DeactivateBlur(target) {
    if (!ActiveBlurs.HasKey(target))
        return
        
    GuiName := GuiNames[target]
    Gui, %GuiName%: Destroy
    WinSet, Transparent, OFF, ahk_id %target%
    
    ActiveBlurs.Delete(target)
    GuiNames.Delete(target)
    LastPos.Delete(target)
}

EnableBlurBehind(hWnd) {
    VarSetCapacity(AccentPolicy, 16, 0)
    NumPut(3, AccentPolicy, 0, "UInt") 
    VarSetCapacity(WINCOMPATTRDATA, A_PtrSize = 8 ? 24 : 12, 0)
    NumPut(19, WINCOMPATTRDATA, 0, "UInt")
    NumPut(&AccentPolicy, WINCOMPATTRDATA, A_PtrSize = 8 ? 8 : 4, "Ptr")
    NumPut(16, WINCOMPATTRDATA, A_PtrSize = 8 ? 16 : 8, "UInt")
    DllCall("user32\SetWindowCompositionAttribute", "Ptr", hWnd, "Ptr", &WINCOMPATTRDATA)
}

GetTrueWindowPos(hWnd, ByRef X, ByRef Y, ByRef W, ByRef H) {
    VarSetCapacity(RECT, 16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hWnd, "UInt", 9, "Ptr", &RECT, "UInt", 16) == 0) {
        X := NumGet(RECT, 0, "Int")
        Y := NumGet(RECT, 4, "Int")
        W := NumGet(RECT, 8, "Int") - X
        H := NumGet(RECT, 12, "Int") - Y
    } else {
        WinGetPos, X, Y, W, H, ahk_id %hWnd%
    }
}
