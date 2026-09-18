; ==============================================================================
; 功能：Windows 多屏智能窗口轮播（完全忽略最小化 + 只显示当前鼠标所在屏幕 + 防崩溃保护）
; 特点：支持按住 Alt 弹出大字界面！每按一下 Tab 切换下一个，松开 Alt 自动消失
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局状态变量
global IsSwitching := false
global ValidWins := []
global CurrentIdx := 1
global MyGui := ""

; ------------------------------------------------------------------------------
; 核心逻辑 1：按住 Alt 键，立刻捕捉鼠标所在屏幕，并弹出该屏幕的【超大字预览菜单】
; ------------------------------------------------------------------------------
~*LAlt::
~*RAlt::
{
    global IsSwitching, ValidWins, CurrentIdx

    if (IsSwitching)
        return

    IsSwitching := true
    ValidWins := []

    ; 获取当前鼠标的绝对坐标
    CoordMode "Mouse", "Screen"
    MouseGetPos &mouseX, &mouseY

    ; 通过 Windows API 获取鼠标坐标所在的显示器句柄
    hMonitor := DllCall("MonitorFromPoint", "Int64", (mouseX & 0xFFFFFFFF) | (mouseY << 32), "UInt", 2, "Ptr")

    ; 1. 收集当前所有可见、未最小化，且属于鼠标所在屏幕的合法窗口
    for this_id in WinGetList()
    {
        try {
            style := WinGetStyle(this_id)
            minMax := WinGetMinMax(this_id)
            title := WinGetTitle(this_id)

            ; 严格过滤：最小化、无标题、隐藏窗口一律不要
            if (minMax == -1 || title == "" || !(style & 0x10000000))
                continue

            if (title == "Program Manager" || title == "Start" || title == "任务切换" || title == "Windows 输入体验")
                continue

            ; 多屏过滤
            winMonitor := DllCall("MonitorFromWindow", "Ptr", this_id, "UInt", 2, "Ptr")
            if (winMonitor != hMonitor)
                continue

            processName := WinGetProcessName(this_id)
            ValidWins.Push({id: this_id, title: title, proc: processName})
        }
    }

    ; 如果当前屏幕没别的窗口可切，直接退出
    if (ValidWins.Length == 0)
    {
        IsSwitching := false
        return
    }

    ; 2. 确定当前活动窗口的初始位置
    CurrentIdx := 1
    try {
        ActiveWin := WinGetID("A")
        for idx, win in ValidWins {
            if (win.id == ActiveWin) {
                CurrentIdx := idx
                break
            }
        }
    }

    ; 3. 绘制超大字体的精美菜单
    CreateBigMenu()

    ; 4. 启动后台异步监控，死死盯住 Alt 键什么时候被松开
    SetTimer WatchAltRelease, 10
}

; ------------------------------------------------------------------------------
; 核心逻辑 2：Alt 按住时，每按一下 Tab，光标和实体窗口同步跳一格
; ------------------------------------------------------------------------------
!Tab::
{
    global IsSwitching, ValidWins, CurrentIdx, MyGui

    ; ─── 🚀 【安全保护锁】 ───
    if (!IsSwitching || ValidWins.Length <= 1 || MyGui == "")
        return

    ; 再次验证数组长度，防止在此期间有窗口消失导致越界
    if (CurrentIdx > ValidWins.Length || CurrentIdx < 1)
        CurrentIdx := 1
    ; ──────────────────────────

    try {
        ; 先把当前行的高亮状态取消
        displayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
        MyGui["Txt" CurrentIdx].SetFont("c333333 norm")
        MyGui["Txt" CurrentIdx].Value := "      " CurrentIdx ".  " displayTitle
    }

    ; 索引向下移动一格（带动态长度防御）
    CurrentIdx := (CurrentIdx >= ValidWins.Length) ? 1 : (CurrentIdx + 1)

    ; 再次双重确保安全
    if (CurrentIdx > ValidWins.Length || CurrentIdx < 1)
        CurrentIdx := 1

    TargetWin := ValidWins[CurrentIdx].id

    ; 瞬间激活目标窗口
    try {
        if WinExist(TargetWin)
            WinActivate(TargetWin)
    }

    try {
        ; 给新选中的这一行加上高亮（大字加粗 + 醒目红色）
        newDisplayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
        MyGui["Txt" CurrentIdx].SetFont("cFF3333 Bold")
        MyGui["Txt" CurrentIdx].Value := "👉 【" CurrentIdx "】 " newDisplayTitle
    }
}

; ------------------------------------------------------------------------------
; 辅助函数：绘制【大字、宽界面】的专属 GUI 悬浮窗
; ------------------------------------------------------------------------------
CreateBigMenu()
{
    global MyGui, ValidWins, CurrentIdx
    if (ValidWins.Length == 0)
        return

    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "大字窗口切换")
    MyGui.BackColor := "FDFDFD"

    MyGui.SetFont("s14 Bold Q5", "Microsoft YaHei")
    MyGui.Add("Text", "w550 c666666", " 🔄  当前屏幕窗口智能切换（已过滤跨屏与最小化）")
    MyGui.Add("Text", "w550 cCCCCCC y+2", "---------------------------------------------------------------------------------")

    MyGui.SetFont("s16 Q5", "Microsoft YaHei")

    for idx, win in ValidWins {
        displayTitle := (StrLen(win.title) > 35) ? SubStr(win.title, 1, 35) "..." : win.title

        if (idx == CurrentIdx) {
            MyGui.SetFont("cFF3333 Bold")
            MyGui.Add("Text", "w550 vTxt" idx " y+12", "👉 【" idx "】 " displayTitle)
        } else {
            MyGui.SetFont("c333333 norm")
            MyGui.Add("Text", "w550 vTxt" idx " y+12", "      " idx ".  " displayTitle)
        }
    }

    MyGui.Add("Text", "h10 y+5", "")

    ; 让提示牌自动显示在鼠标所在的那个屏幕中央
    CoordMode "Mouse", "Screen"
    MouseGetPos &mX, &mY
    monitorIndex := DllCall("MonitorFromPoint", "Int64", (mX & 0xFFFFFFFF) | (mY << 32), "UInt", 2, "Ptr")

    NumPut("UInt", 40, NumObj := Buffer(40, 0))
    if DllCall("GetMonitorInfo", "Ptr", monitorIndex, "Ptr", NumObj) {
        WL := NumGet(NumObj, 20, "Int")
        WT := NumGet(NumObj, 24, "Int")
        WR := NumGet(NumObj, 28, "Int")
        WB := NumGet(NumObj, 32, "Int")

        guiX := WL + ((WR - WL) // 2) - 275
        guiY := WT + ((WB - WT) // 2) - 150
        MyGui.Show("X" guiX " Y" guiY)
    } else {
        MyGui.Show("Center")
    }
}

; ------------------------------------------------------------------------------
; 辅助函数：异步监控 Alt 松开状态，瞬间销毁大界面
; ------------------------------------------------------------------------------
WatchAltRelease()
{
    global IsSwitching, ValidWins, MyGui
    if (!GetKeyState("LAlt", "P") && !GetKeyState("RAlt", "P"))
    {
        SetTimer WatchAltRelease, 0

        if (MyGui != "") {
            try MyGui.Destroy()
            MyGui := ""
        }

        IsSwitching := false
        ValidWins := []
    }
}
