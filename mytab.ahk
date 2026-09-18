; ==============================================================================
; 功能：Windows 全局智能窗口轮播（完全忽略所有最小化窗口 + 巨幕大字预览菜单）
; 特点：修复 Normal 语法错误。按住 Alt 弹出超大字的精美界面！每按一下 Tab 切换下一个，松开 Alt 自动消失
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局状态变量
global IsSwitching := false
global ValidWins := []
global CurrentIdx := 1
global MyGui := ""       ; 用 Gui 替代原先的 ToolTip

; ------------------------------------------------------------------------------
; 核心逻辑 1：按住 Alt 键，立刻生成并弹出【超大字预览菜单】
; ------------------------------------------------------------------------------
~*LAlt::
~*RAlt::
{
    global IsSwitching, ValidWins, CurrentIdx

    if (IsSwitching)
        return

    IsSwitching := true
    ValidWins := []

    ; 1. 收集当前所有可见、未最小化的合法窗口
    for this_id in WinGetList()
    {
        style := WinGetStyle(this_id)
        minMax := WinGetMinMax(this_id)
        title := WinGetTitle(this_id)

        ; 严格过滤：最小化、无标题、隐藏窗口一律不要
        if (minMax == -1 || title == "" || !(style & 0x10000000))
            continue

        if (title == "Program Manager" || title == "Start" || title == "任务切换" || title == "Windows 输入体验")
            continue

        try processName := WinGetProcessName(this_id)
        catch
            processName := "Unknown"

        ValidWins.Push({id: this_id, title: title, proc: processName})
    }

    if (ValidWins.Length <= 1)
        return

    ; 2. 确定当前 activity 窗口的初始位置
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

    ; 3. 调用函数：绘制超大字体的精美菜单
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

    ; 先把当前行的高亮状态取消（恢复普通大字样式：使用 AHK v2 标准的 norm 关键字）
    displayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
    MyGui["Txt" CurrentIdx].SetFont("c333333 norm") ; 👈 已修正为小写 norm
    MyGui["Txt" CurrentIdx].Value := "      " CurrentIdx ".  " displayTitle

    ; 索引向下移动一格
    CurrentIdx := (CurrentIdx >= ValidWins.Length) ? 1 : (CurrentIdx + 1)
    TargetWin := ValidWins[CurrentIdx].id

    ; 瞬间激活目标窗口
    if WinExist(TargetWin)
        WinActivate(TargetWin)

    ; 给新选中的这一行加上高亮（大字加粗 + 醒目红色）
    newDisplayTitle := (StrLen(ValidWins[CurrentIdx].title) > 35) ? SubStr(ValidWins[CurrentIdx].title, 1, 35) "..." : ValidWins[CurrentIdx].title
    MyGui["Txt" CurrentIdx].SetFont("cFF3333 Bold")
    MyGui["Txt" CurrentIdx].Value := "👉 【" CurrentIdx "】 " newDisplayTitle
}

; ------------------------------------------------------------------------------
; 辅助函数：绘制【大字、宽界面】的专属 GUI 悬浮窗
; ------------------------------------------------------------------------------
CreateBigMenu()
{
    global MyGui, ValidWins, CurrentIdx
    if (ValidWins.Length == 0)
        return

    ; 创建一个置顶、无系统边框、带细边框的精致窗口
    MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "大字窗口切换")

    ; 🎨 设置皮肤：纯白底色
    MyGui.BackColor := "FDFDFD"

    ; 📐 设置顶部标题栏字体：14号大字，微软雅黑色调
    MyGui.SetFont("s14 Bold Q5", "Microsoft YaHei")
    MyGui.Add("Text", "w550 c666666", " 🔄  窗口智能切换（已过滤所有最小化应用）")
    MyGui.Add("Text", "w550 cCCCCCC y+2", "---------------------------------------------------------------------------------")

    ; 📐 设置列表内容字体：16号巨幕大字！保证看得很清楚
    MyGui.SetFont("s16 Q5", "Microsoft YaHei")

    for idx, win in ValidWins {
        displayTitle := (StrLen(win.title) > 35) ? SubStr(win.title, 1, 35) "..." : win.title

        ; 使用 vTxt1, vTxt2 动态标记每一行，方便后续 Tab 键实时刷新
        if (idx == CurrentIdx) {
            ; 初始高亮的行：大字加粗 + 红色
            MyGui.SetFont("cFF3333 Bold")
            MyGui.Add("Text", "w550 vTxt" idx " y+12", "👉 【" idx "】 " displayTitle)
        } else {
            ; 普通行：暗灰色（这里同样修正为标准的 c333333 norm）
            MyGui.SetFont("c333333 norm") ; 👈 已修正为小写 norm
            MyGui.Add("Text", "w550 vTxt" idx " y+12", "      " idx ".  " displayTitle)
        }
    }

    ; 在下方留出一点空气感边距
    MyGui.Add("Text", "h10 y+5", "")

    ; 居中显示这个超大提示牌
    MyGui.Show("Center")
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

        ; 销毁自制的大界面，不常驻内存
        if (MyGui != "") {
            MyGui.Destroy()
            MyGui := ""
        }

        IsSwitching := false
        ValidWins := []
    }
}
