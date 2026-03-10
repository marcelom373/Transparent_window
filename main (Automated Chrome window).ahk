#Persistent
SetBatchLines, -1 ; Hace que el script corra a máxima velocidad para que el seguimiento sea súper fluido

; --- MATRICES PARA GESTIONAR MÚLTIPLES VENTANAS ---
Global ActiveBlurs := {}      ; Guarda qué ventanas tienen el efecto activo (ID Ventana -> ID Bloque Blur)
Global GuiNames := {}         ; Guarda los nombres internos de cada bloque GUI
Global LastPos := {}          ; Guarda la última posición conocida de cada ventana
Global DisabledChrome := {}   ; Memoria de los Chrome que apagaste manualmente

; Iniciamos los temporizadores
SetTimer, AutoChromeCheck, 500
SetTimer, FollowWindows, 10

; --- ATAJO DE TECLADO MANUAL (Ctrl + Alt + Clic Derecho) ---
^!RButton::
    WinGet, active_id, ID, A
    
    ; Si la ventana actual ya tiene el efecto encendido...
    if (ActiveBlurs.HasKey(active_id))
    {
        ; Recordar si es Chrome para no volver a encenderlo automáticamente
        WinGet, procName, ProcessName, ahk_id %active_id%
        if (procName = "chrome.exe")
            DisabledChrome[active_id] := true
            
        DeactivateBlur(active_id)
    }
    else
    {
        ; Si estaba apagado, lo encendemos (y olvidamos si lo habíamos bloqueado)
        DisabledChrome.Delete(active_id) 
        ActivateBlur(active_id)
    }
return

; --- VIGILANTE AUTOMÁTICO (AHORA MULTIVENTANA) ---
AutoChromeCheck:
    WinGet, active_id, ID, A
    WinGet, procName, ProcessName, ahk_id %active_id%
    
    if (procName = "chrome.exe")
    {
        WinGetTitle, title, ahk_id %active_id%
        
        ; Si es Chrome, tiene título, NO está en la lista de activos y NO está bloqueado...
        if (title != "" && !ActiveBlurs.HasKey(active_id) && !DisabledChrome.HasKey(active_id))
        {
            ActivateBlur(active_id)
        }
    }
return

; --- BUCLE SEGUIDOR MULTIVENTANA ---
FollowWindows:
    ; Recorremos TODAS las ventanas que tienen el efecto activo actualmente
    For target, blurGui in ActiveBlurs
    {
        ; 1. Si la ventana se cerró, destruimos su bloque borroso
        if !WinExist("ahk_id " target)
        {
            DeactivateBlur(target)
            continue
        }
        
        WinGet, isMin, MinMax, ahk_id %target%
        GuiName := GuiNames[target]
        
        ; 2. Si se minimizó, ocultamos su bloque
        if (isMin = -1)
        {
            Gui, %GuiName%: Hide
            LastPos[target] := "" 
            continue
        }
        
        ; 3. Comprobar si se movió o redimensionó
        GetTrueWindowPos(target, tX, tY, tW, tH)
        pos := LastPos[target]
        
        if (!IsObject(pos) || tX != pos.X || tY != pos.Y || tW != pos.W || tH != pos.H)
        {
            Gui, %GuiName%: Show, NA
            WinMove, ahk_id %blurGui%,, %tX%, %tY%, %tW%, %tH%
            LastPos[target] := {X: tX, Y: tY, W: tW, H: tH}
        }
        
        ; 4. MAGIA DE CAPAS: Comprueba qué ventana está justo debajo del navegador
        ; GW_HWNDNEXT = 2 (Obtiene la ventana inmediatamente debajo en el Z-Order)
        hwndBelow := DllCall("GetWindow", "Ptr", target, "UInt", 2, "Ptr")
        
        ; Si el bloque borroso no está justo detrás, lo forzamos a colocarse ahí
        if (hwndBelow != blurGui)
        {
            DllCall("user32.dll\SetWindowPos", "Ptr", blurGui, "Ptr", target, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
        }
    }
return

; --- FUNCIONES PRINCIPALES ---

ActivateBlur(target) {
    if (ActiveBlurs.HasKey(target))
        return ; Ya está activo
        
    ; Creamos un nombre único para el bloque GUI de esta ventana específica
    GuiName := "Blur_" . target
    
    Gui, %GuiName%: New, +HwndhBlurBg -Caption +ToolWindow -DPIScale +E0x08000000
    Gui, %GuiName%: Color, 111111 
    
    EnableBlurBehind(hBlurBg)
    
    GetTrueWindowPos(target, tX, tY, tW, tH)
    LastPos[target] := {X: tX, Y: tY, W: tW, H: tH}
    
    Gui, %GuiName%: Show, x%tX% y%tY% w%tW% h%tH% NA
    WinSet, Transparent, 220, ahk_id %target%
    
    ; Colocar justo detrás
    DllCall("user32.dll\SetWindowPos", "Ptr", hBlurBg, "Ptr", target, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    
    ; Guardamos los datos en las matrices
    ActiveBlurs[target] := hBlurBg
    GuiNames[target] := GuiName
}

DeactivateBlur(target) {
    if (!ActiveBlurs.HasKey(target))
        return
        
    GuiName := GuiNames[target]
    Gui, %GuiName%: Destroy
    WinSet, Transparent, OFF, ahk_id %target%
    
    ; Limpiamos las matrices
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
