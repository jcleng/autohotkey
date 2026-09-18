; ==============================================================================
; 功能：Windows 多屏智能窗口轮播（忽略最小化 + 鼠标屏幕感知 + 【官方应用图标显示】）
; 特点：支持按住 Alt 弹出精美图文大菜单！每按一下 Tab 切换下一个，松开 Alt 自动消失
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局状态变量
global IsSwitching := false
global ValidWins := []
global CurrentIdx := 1
global MyGui := ""

; ------------------------------------------------------------------------------
; 核心逻辑 1：按住 Alt 键，立刻捕捉鼠标所在屏幕，并弹出带【应用图标】的大菜单
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

            processPath := WinGetProcessPath(this_id)
            ValidWins.Push({id: this_id, title: title, path: processPath})
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

    ; 3. 绘制带有图标的超大字体精美菜单
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

    if (!IsSwitching || ValidWins.Length <= 1 || MyGui == "")
        return

    if (CurrentIdx > ValidWins.Length || CurrentIdx < 1)
        CurrentIdx := 1

    try {
        ; ─── 取消旧行的高亮状态 ───
        MyGui["Arrow" CurrentIdx].Value := "      " ; 清空旧行的 👉 箭头
        displayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
        MyGui["Txt" CurrentIdx].SetFont("c333333 norm")
        MyGui["Txt" CurrentIdx].Value := displayTitle
    }

    ; 索引向下移动一格
    CurrentIdx := (CurrentIdx >= ValidWins.Length) ? 1 : (CurrentIdx + 1)

    if (CurrentIdx > ValidWins.Length || CurrentIdx < 1)
        CurrentIdx := 1

    TargetWin := ValidWins[CurrentIdx].id

    ; 瞬间激活目标窗口
    try {
        if WinExist(TargetWin)
            WinActivate(TargetWin)
    }

    try {
        ; ─── 激活新行的高亮状态 ───
        MyGui["Arrow" CurrentIdx].Value := "👉 " ; 亮起新行的 👉 箭头
        newDisplayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
        MyGui["Txt" CurrentIdx].SetFont("cFF3333 Bold")
        MyGui["Txt" CurrentIdx].Value := "【" CurrentIdx "】 " newDisplayTitle
    }
}

; ------------------------------------------------------------------------------
; 辅助函数：绘制【大字 + 软件图标 + 宽界面】的专属 GUI 悬浮窗
; ------------------------------------------------------------------------------
CreateBigMenu()
{
    global MyGui, ValidWins, CurrentIdx
    if (ValidWins.Length == 0)
        return

    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "大字图标窗口切换")
    MyGui.BackColor := "FDFDFD"

    ; 顶层头部
    MyGui.SetFont("s13 Bold Q5", "Microsoft YaHei")
    MyGui.Add("Text", "w580 c666666 x20 y15", " 🔄  当前屏幕窗口智能切换（已过滤跨屏与最小化）")
    MyGui.Add("Text", "w580 cCCCCCC x20 y+2", "-----------------------------------------------------------------------------------")

    ; 循环渲染列表（图文并排布局）
    startY := 55
    for idx, win in ValidWins {
        displayTitle := (StrLen(win.title) > 35) ? SubStr(win.title, 1, 35) "..." : win.title
        startY += 42 ; 每行纵向间隔

        ; 1. 添加 👉 箭头占位符
        arrowStr := (idx == CurrentIdx) ? "👉 " : "      "
        MyGui.SetFont("s16 Bold Q5", "Microsoft YaHei")
        MyGui.Add("Text", "x15 y" startY " w45 vArrow" idx, arrowStr)

        ; 2. 动态提取并添加软件的【官方大图标】
        ; HICON: 获取 32x32 的高清图标句柄
        hIcon := 0
        if (win.path != "") {
            DllCall("PrivateExtractIcons", "Str", win.path, "Int", 0, "Int", 32, "Int", 32, "Ptr*", &hIcon, "Ptr*", 0, "UInt", 1, "UInt", 0)
        }

        ; 将图标加到界面里。如果提取失败，AHK 会自动使用默认空白图标兜底
        if (hIcon) {
            MyGui.Add("Pic", "x60 y" startY+2 " w28 h28", "HICON:" hIcon)
        } else {
            MyGui.Add("Pic", "x60 y" startY+2 " w28 h28", "shell32.dll,3") ; 无法提取时用系统默认窗口图标
        }

        ; 3. 添加软件标题文本
        MyGui.SetFont("s16 Q5", "Microsoft YaHei")
        if (idx == CurrentIdx) {
            MyGui.SetFont("cFF3333 Bold")
            MyGui.Add("Text", "x100 y" startY " w460 h32 vTxt" idx, "【" idx "】 " displayTitle)
        } else {
            MyGui.SetFont("c333333 norm")
            MyGui.Add("Text", "x100 y" startY " w460 h32 vTxt" idx, displayTitle)
        }
    }

    ; 底部留白
    MyGui.Add("Text", "h15 y+5", "")

    ; 计算并将菜单放置在当前鼠标所在屏幕的正中央
    CoordMode "Mouse", "Screen"
    MouseGetPos &mX, &mY
    monitorIndex := DllCall("MonitorFromPoint", "Int64", (mX & 0xFFFFFFFF) | (mY << 32), "UInt", 2, "Ptr")

    NumPut("UInt", 40, NumObj := Buffer(40, 0))
    if DllCall("GetMonitorInfo", "Ptr", monitorIndex, "Ptr", NumObj) {
        WL := NumGet(NumObj, 20, "Int")
        WT := NumGet(NumObj, 24, "Int")
        WR := NumGet(NumObj, 28, "Int")
        WB := NumGet(NumObj, 32, "Int")

        guiX := WL + ((WR - WL) // 2) - 300
        guiY := WT + ((WB - WT) // 2) - ((startY + 40) // 2)
        MyGui.Show("X" guiX " Y" guiY " w600")
    } else {
        MyGui.Show("Center w600")
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
