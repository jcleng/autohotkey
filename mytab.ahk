; ==============================================================================
; 功能：Windows 多屏智能窗口轮播（忽略最小化 + 鼠标屏幕感知 + 官方应用图标 + 组合键触发）
; 特点：单独按 Alt 绝不弹窗！必须 Alt+Tab 首次按下才显示大菜单，后续 Tab 连续滚动
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局状态变量
global IsSwitching := false
global ValidWins := []
global CurrentIdx := 1
global MyGui := ""

; ------------------------------------------------------------------------------
; 核心修改：抛弃 ~LAlt 独立监听，直接由 !Tab（Alt+Tab）组合键作为唯一启动入口
; ------------------------------------------------------------------------------
!Tab::
{
    global IsSwitching, ValidWins, CurrentIdx, MyGui

    ; 1. 如果还没进入切换状态（这是本次操作按下的第一下 Tab）
    if (!IsSwitching)
    {
        IsSwitching := true
        ValidWins := []

        ; 获取当前鼠标的绝对坐标
        CoordMode "Mouse", "Screen"
        MouseGetPos &mouseX, &mouseY

        ; 获取鼠标坐标所在的显示器句柄
        hMonitor := DllCall("MonitorFromPoint", "Int64", (mouseX & 0xFFFFFFFF) | (mouseY << 32), "UInt", 2, "Ptr")

        ; 收集当前所有可见、未最小化，且属于鼠标所在屏幕的合法窗口
        for this_id in WinGetList()
        {
            try {
                style := WinGetStyle(this_id)
                minMax := WinGetMinMax(this_id)
                title := WinGetTitle(this_id)

                ; 基础过滤：最小化、无标题、不可见窗口
                if (minMax == -1 || title == "" || !(style & 0x10000000))
                    continue

                ; 🚀 核心新增：过滤软件名称/标题中带有 `-siw` 的窗口
                if (InStr(title, "-siw"))
                    continue

                ; 过滤系统特定不参与切换的组件
                if (title == "Program Manager" || title == "Start" || title == "任务切换" || title == "Windows 输入体验")
                    continue

                winMonitor := DllCall("MonitorFromWindow", "Ptr", this_id, "UInt", 2, "Ptr")
                if (winMonitor != hMonitor)
                    continue

                processPath := WinGetProcessPath(this_id)
                ValidWins.Push({id: this_id, title: title, path: processPath})
            }
        }

        ; 如果当前屏幕没有窗口，或者只有1个窗口，无需切换预览，直接复位退出
        if (ValidWins.Length <= 1)
        {
            IsSwitching := false
            return
        }

        ; 确定当前活跃窗口的初始位置
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

        ; ─── 🚀 【关键策略：初次按下就直接移动到下一个窗口】 ───
        CurrentIdx := (CurrentIdx >= ValidWins.Length) ? 1 : (CurrentIdx + 1)
        TargetWin := ValidWins[CurrentIdx].id
        try {
            if WinExist(TargetWin)
                WinActivate(TargetWin)
        }

        ; 首次按下，立即绘制包含官方大图标的预览菜单
        CreateBigMenu()

        ; 启动后台异步监控，死死盯住 Alt 键什么时候被松开
        SetTimer WatchAltRelease, 10
        return ; 首次触发收尾，等待下一次 Tab
    }

    ; 2. 如果已经在切换状态中（用户按住 Alt 没松，再次敲下了 Tab 键）
    if (ValidWins.Length <= 1 || MyGui == "")
        return

    if (CurrentIdx > ValidWins.Length || CurrentIdx < 1)
        CurrentIdx := 1

    try {
        ; 取消旧行的高亮状态
        MyGui["Arrow" CurrentIdx].Value := "      "
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
        ; 激活新行的高亮状态
        MyGui["Arrow" CurrentIdx].Value := "👉 "
        newDisplayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
        MyGui["Txt" CurrentIdx].SetFont("cFF3333 Bold")
        MyGui["Txt" CurrentIdx].Value := "【" CurrentIdx "】 " newDisplayTitle
    }
}

; ------------------------------------------------------------------------------
; 辅助函数：绘制【大字 + 软件图标】的专属 GUI 悬浮窗
; ------------------------------------------------------------------------------
CreateBigMenu()
{
    global MyGui, ValidWins, CurrentIdx
    if (ValidWins.Length == 0)
        return

    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "大字图标窗口切换")
    MyGui.BackColor := "FDFDFD"

    MyGui.SetFont("s13 Bold Q5", "Microsoft YaHei")
    MyGui.Add("Text", "w580 c666666 x20 y15", " 🔄  当前屏幕窗口智能切换（已过滤跨屏与最小化）")
    MyGui.Add("Text", "w580 cCCCCCC x20 y+2", "-----------------------------------------------------------------------------------")

    startY := 55
    for idx, win in ValidWins {
        displayTitle := (StrLen(win.title) > 35) ? SubStr(win.title, 1, 35) "..." : win.title
        startY += 42

        arrowStr := (idx == CurrentIdx) ? "👉 " : "      "
        MyGui.SetFont("s16 Bold Q5", "Microsoft YaHei")
        MyGui.Add("Text", "x15 y" startY " w45 vArrow" idx, arrowStr)

        hIcon := 0
        if (win.path != "") {
            DllCall("PrivateExtractIcons", "Str", win.path, "Int", 0, "Int", 32, "Int", 32, "Ptr*", &hIcon, "Ptr*", 0, "UInt", 1, "UInt", 0)
        }

        if (hIcon) {
            MyGui.Add("Pic", "x60 y" startY+2 " w28 h28", "HICON:" hIcon)
        } else {
            MyGui.Add("Pic", "x60 y" startY+2 " w28 h28", "shell32.dll,3")
        }

        MyGui.SetFont("s16 Q5", "Microsoft YaHei")
        if (idx == CurrentIdx) {
            MyGui.SetFont("cFF3333 Bold")
            MyGui.Add("Text", "x100 y" startY " w460 h32 vTxt" idx, "【" idx "】 " displayTitle)
        } else {
            MyGui.SetFont("c333333 norm")
            MyGui.Add("Text", "x100 y" startY " w460 h32 vTxt" idx, displayTitle)
        }
    }

    MyGui.Add("Text", "h15 y+5", "")

    ; 将菜单放置在鼠标所在的显示器正中央
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
; 辅助函数：异步监控 Alt 松开状态
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
