#Persistent ; Asegura que el script se mantenga ejecutándose en segundo plano

Global IsBlurActive := false
Global TargetHWND := 0
Global hBlurBg := 0
Global LastX := "", LastY := "", LastW := "", LastH := ""
Global WasActive := false
Global ChromeDisabledHWND := 0 ; Memoria para saber si apagaste Chrome manualmente

; Iniciar el vigilante que busca a Chrome (se ejecuta cada medio segundo)
SetTimer, AutoChromeCheck, 500

; --- ATAJO DE TECLADO MANUAL (Ctrl + Alt + Clic Derecho) ---
^!RButton::
    WinGet, active_id, ID, A
    
    if (IsBlurActive)
    {
        ; Si el efecto está activo en la ventana actual, lo apagamos
        if (active_id == TargetHWND)
        {
            ; Si es Chrome, recordamos que lo apagaste a propósito para no auto-activarlo de nuevo
            WinGet, procName, ProcessName, ahk_id %TargetHWND%
            if (procName = "chrome.exe")
                ChromeDisabledHWND := TargetHWND
                
            DeactivateBlur()
        }
        else
        {
            ; Si está activo en otra ventana y haces clic en una nueva, mudamos el efecto a la nueva
            DeactivateBlur()
            ChromeDisabledHWND := 0
            ActivateBlur(active_id)
        }
    }
    else
    {
        ; Encendido manual desde cero
        ChromeDisabledHWND := 0 ; Reseteamos la memoria por si era Chrome
        ActivateBlur(active_id)
    }
return

; --- VIGILANTE AUTOMÁTICO PARA CHROME ---
AutoChromeCheck:
    ; Solo revisar si el efecto está apagado actualmente
    if (!IsBlurActive)
    {
        WinGet, active_id, ID, A
        WinGet, procName, ProcessName, ahk_id %active_id%
        
        ; Si la ventana activa es Chrome...
        if (procName = "chrome.exe")
        {
            ; Evitar ventanas invisibles o popups sin título de Chrome
            WinGetTitle, title, ahk_id %active_id%
            
            ; Si tiene título y NO es la ventana que apagamos manualmente...
            if (title != "" && active_id != ChromeDisabledHWND)
            {
                ActivateBlur(active_id) ; ¡Magia automática!
            }
        }
    }
return

; --- BUCLE SEGUIDOR (El que mantiene el bloque detrás) ---
FollowWindow:
    if !WinExist("ahk_id " TargetHWND)
    {
        DeactivateBlur()
        return
    }
    
    WinGet, isMin, MinMax, ahk_id %TargetHWND%
    if (isMin = -1)
    {
        Gui, BlurBg: Hide
        LastX := "" 
        return
    }
    
    GetTrueWindowPos(TargetHWND, tX, tY, tW, tH)
    
    if (tX != LastX || tY != LastY || tW != LastW || tH != LastH)
    {
        Gui, BlurBg: Show, NA
        WinMove, ahk_id %hBlurBg%,, %tX%, %tY%, %tW%, %tH%
        LastX := tX, LastY := tY, LastW := tW, LastH := tH
    }
    
    WinGet, ActiveHwnd, ID, A
    if (ActiveHwnd == TargetHWND)
    {
        if (!WasActive)
        {
            DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", TargetHWND, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
            WasActive := true
        }
    }
    else if (ActiveHwnd != hBlurBg)
    {
        WasActive := false
    }
return

; --- FUNCIONES PRINCIPALES ---

ActivateBlur(hWnd) {
    TargetHWND := hWnd
    Gui, BlurBg: New, +HwndhBlurBg -Caption +ToolWindow -DPIScale +E0x08000000
    Gui, BlurBg: Color, 111111 
    
    EnableBlurBehind(hBlurBg)
    
    GetTrueWindowPos(TargetHWND, tX, tY, tW, tH)
    LastX := tX, LastY := tY, LastW := tW, LastH := tH
    
    Gui, BlurBg: Show, x%tX% y%tY% w%tW% h%tH% NA
    WinSet, Transparent, 220, ahk_id %TargetHWND%
    
    DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", TargetHWND, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    WasActive := true
    
    IsBlurActive := true
    SetTimer, FollowWindow, 10
}

DeactivateBlur() {
    SetTimer, FollowWindow, Off
    Gui, BlurBg: Destroy
    WinSet, Transparent, OFF, ahk_id %TargetHWND%
    IsBlurActive := false
    TargetHWND := 0
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