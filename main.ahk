Global IsBlurActive := false
Global TargetHWND := 0
Global hBlurBg := 0
Global LastX := "", LastY := "", LastW := "", LastH := ""
Global WasActive := false

^!RButton::
    if (IsBlurActive)
    {
        ; Apagar todo
        SetTimer, FollowWindow, Off
        Gui, BlurBg: Destroy
        WinSet, Transparent, OFF, ahk_id %TargetHWND%
        IsBlurActive := false
        TargetHWND := 0
    }
    else
    {
        WinGet, TargetHWND, ID, A
        
        ; +E0x08000000 es el estilo WS_EX_NOACTIVATE (evita que el bloque robe el foco)
        Gui, BlurBg: New, +HwndhBlurBg -Caption +ToolWindow -DPIScale +E0x08000000
        Gui, BlurBg: Color, 111111 
        
        EnableBlurBehind(hBlurBg)
        
        ; Obtener la posición REAL (sin sombras invisibles)
        GetTrueWindowPos(TargetHWND, tX, tY, tW, tH)
        LastX := tX, LastY := tY, LastW := tW, LastH := tH
        
        Gui, BlurBg: Show, x%tX% y%tY% w%tW% h%tH% NA
        WinSet, Transparent, 220, ahk_id %TargetHWND%
        
        ; Ajustar la capa inicial
        DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", TargetHWND, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
        WasActive := true
        
        IsBlurActive := true
        SetTimer, FollowWindow, 10
    }
return

FollowWindow:
    if !WinExist("ahk_id " TargetHWND)
    {
        SetTimer, FollowWindow, Off
        Gui, BlurBg: Destroy
        IsBlurActive := false
        return
    }
    
    WinGet, isMin, MinMax, ahk_id %TargetHWND%
    if (isMin = -1)
    {
        Gui, BlurBg: Hide
        LastX := "" ; Forzamos actualización al restaurar
        return
    }
    
    ; 1. Arreglar el desfase flotante (medir tamaño real)
    GetTrueWindowPos(TargetHWND, tX, tY, tW, tH)
    
    ; Solo mover si la ventana REALMENTE se movió (Evita el parpadeo constante)
    if (tX != LastX || tY != LastY || tW != LastW || tH != LastH)
    {
        Gui, BlurBg: Show, NA
        WinMove, ahk_id %hBlurBg%,, %tX%, %tY%, %tW%, %tH%
        LastX := tX, LastY := tY, LastW := tW, LastH := tH
    }
    
    ; 2. Arreglar el parpadeo de capas (Z-Order)
    WinGet, ActiveHwnd, ID, A
    if (ActiveHwnd == TargetHWND)
    {
        ; Si Chrome está activo pero antes no lo estaba, ajustamos la capa UNA VEZ
        if (!WasActive)
        {
            DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", TargetHWND, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
            WasActive := true
        }
    }
    else if (ActiveHwnd != hBlurBg)
    {
        ; Si hicimos clic en otra ventana, registramos que Chrome ya no es el activo
        WasActive := false
    }
return

; --- FUNCIONES AUXILIARES ---

EnableBlurBehind(hWnd) {
    VarSetCapacity(AccentPolicy, 16, 0)
    NumPut(3, AccentPolicy, 0, "UInt") 
    VarSetCapacity(WINCOMPATTRDATA, A_PtrSize = 8 ? 24 : 12, 0)
    NumPut(19, WINCOMPATTRDATA, 0, "UInt")
    NumPut(&AccentPolicy, WINCOMPATTRDATA, A_PtrSize = 8 ? 8 : 4, "Ptr")
    NumPut(16, WINCOMPATTRDATA, A_PtrSize = 8 ? 16 : 8, "UInt")
    DllCall("user32\SetWindowCompositionAttribute", "Ptr", hWnd, "Ptr", &WINCOMPATTRDATA)
}

; Extrae el tamaño visual real ignorando las sombras de Windows 10/11
GetTrueWindowPos(hWnd, ByRef X, ByRef Y, ByRef W, ByRef H) {
    VarSetCapacity(RECT, 16, 0)
    ; 9 = DWMWA_EXTENDED_FRAME_BOUNDS
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hWnd, "UInt", 9, "Ptr", &RECT, "UInt", 16) == 0) {
        X := NumGet(RECT, 0, "Int")
        Y := NumGet(RECT, 4, "Int")
        W := NumGet(RECT, 8, "Int") - X
        H := NumGet(RECT, 12, "Int") - Y
    } else {
        WinGetPos, X, Y, W, H, ahk_id %hWnd%
    }
}