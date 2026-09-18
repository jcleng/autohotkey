; ==============================================================================
; 功能：Windows 全局智能窗口轮播（完全忽略所有最小化窗口 + 完美原生按键体验）
; 特点：按住 Alt 瞬间弹出 Tips 列表预览！纯物理驱动，每按一下 Tab 才精准切下一个
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局状态变量
global IsSwitching := false
global ValidWins := []
global CurrentIdx := 1

; ------------------------------------------------------------------------------
; 核心逻辑 1：只要用户按下 Alt 键（无论左还是右），立刻生成并弹出 Tips 列表预览
; ------------------------------------------------------------------------------
~*LAlt::
~*RAlt::
{
    global IsSwitching, ValidWins, CurrentIdx

    ; 如果已经在切换状态中，不要重复触发
    if (IsSwitching)
        return

    IsSwitching := true
    ValidWins := []

    ; 1. 立刻收集当前所有可见、未最小化的合法窗口
    for this_id in WinGetList()
    {
        style := WinGetStyle(this_id)
        minMax := WinGetMinMax(this_id)
        title := WinGetTitle(this_id)

        ; 严格过滤：最小化(minMax==-1)、无标题、隐藏窗口一律不要
        if (minMax == -1 || title == "" || !(style & 0x10000000))
            continue

        if (title == "Program Manager" || title == "Start" || title == "任务切换" || title == "Windows 输入体验")
            continue

        try processName := WinGetProcessName(this_id)
        catch
            processName := "Unknown"

        ValidWins.Push({id: this_id, title: title, proc: processName})
    }

    ; 如果没别的窗口可预览，直接退出
    if (ValidWins.Length <= 1)
        return

    ; 2. 确定当前活动窗口在列表中的初始位置（默认高亮当前窗口）
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

    ; 3. 按住 Alt 的瞬间，不等按 Tab，直接把 Tips 列表渲染并显示出来
    ShowSwitchingTips()

    ; 4. 启动后台异步监控，死死盯住 Alt 键什么时候被松开
    SetTimer WatchAltRelease, 10
}

; ------------------------------------------------------------------------------
; 核心逻辑 2：在 Alt 按住的前提下，只有每按一下 Tab，光标和实体窗口才向下跳一格
; ------------------------------------------------------------------------------
!Tab::
{
    global IsSwitching, ValidWins, CurrentIdx

    ; 防御性代码：如果因为系统原因没触发 Alt 监听，这里进行兜底补发
    if (!IsSwitching || ValidWins.Length <= 1)
        return

    ; 只有每次按下 Tab，索引才真正动一下
    CurrentIdx := (CurrentIdx >= ValidWins.Length) ? 1 : (CurrentIdx + 1)
    TargetWin := ValidWins[CurrentIdx].id

    ; 瞬间激活目标窗口
    if WinExist(TargetWin)
        WinActivate(TargetWin)

    ; 刷新 Tips 列表中的 👉 光标位置
    ShowSwitchingTips()
}

; ------------------------------------------------------------------------------
; 辅助函数：绘制精美的居中 Tips 提示框
; ------------------------------------------------------------------------------
ShowSwitchingTips()
{
    global ValidWins, CurrentIdx
    if (ValidWins.Length == 0)
        return

    CoordMode "ToolTip", "Screen"
    TipsText := "🔄 窗口切换中（已过滤最小化）`n--------------------------------------------`n"
    for idx, win in ValidWins {
        ; 截取过长的标题，防止 Tips 撑满屏幕
        displayTitle := (StrLen(win.title) > 40) ? SubStr(win.title, 1, 40) "..." : win.title

        if (idx == CurrentIdx)
            TipsText .= "👉 【" idx "】 " displayTitle " [" win.proc "]`n" ; 当前高亮
        else
            TipsText .= "      " idx ". " displayTitle "`n"
    }
    ; 始终稳定显示在屏幕正中央
    ToolTip(TipsText, A_ScreenWidth // 2 - 150, A_ScreenHeight // 2 - 100)
}

; ------------------------------------------------------------------------------
; 辅助函数：异步监控 Alt 松开状态
; ------------------------------------------------------------------------------
WatchAltRelease()
{
    global IsSwitching, ValidWins
    ; 检测左 Alt 和右 Alt 的真实物理状态，如果都松开了
    if (!GetKeyState("LAlt", "P") && !GetKeyState("RAlt", "P"))
    {
        SetTimer WatchAltRelease, 0  ; 关闭监控定时器
        ToolTip()                    ; 瞬间关闭并移除屏幕中央的 Tips 提示框
        IsSwitching := false         ; 重置状态，等待下一次完整的切换
        ValidWins := []
    }
}
