; ==============================================================================
; 功能：Ctrl + Alt + Shift + T 文本万能工具箱（修复 Normal 语法错误版）
; 特点：大字菜单预览，集成常见文本格式化，带剪贴板保护与翻译接口防挂锁
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

global SelectedText := ""
global ToolBoxGui := ""

^+!t::
{
    global SelectedText, ToolBoxGui

    ; 1. 备份并捕获当前选中的文本
    OldClipboard := A_Clipboard
    A_Clipboard := ""
    Send "^c"

    if !ClipWait(0.4) {
        if (OldClipboard == "") {
            ToolTip "❌ 未选中任何文本，且剪贴板为空"
            SetTimer () => ToolTip(), -2000
            A_Clipboard := OldClipboard
            return
        }
        SelectedText := OldClipboard
    } else {
        SelectedText := A_Clipboard
    }

    A_Clipboard := OldClipboard

    if (ToolBoxGui != "") {
        ToolBoxGui.Destroy()
        ToolBoxGui := ""
    }

    ; 2. 构建高颜值大字功能列表窗口
    ToolBoxGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "文本万能工具箱")
    ToolBoxGui.BackColor := "FDFDFD"

    ; 头部提示
    ToolBoxGui.SetFont("s13 Bold Q5", "Microsoft YaHei")
    ToolBoxGui.Add("Text", "w450 c666666 x20 y15", "🛠️ 文本万能工具箱（请选择要执行的操作）")
    ToolBoxGui.Add("Text", "w450 cCCCCCC x20 y+2", "-------------------------------------------------------------------------")

    ; 📐 按钮列表样式：已修正为 v2 标准的 norm 关键字
    ToolBoxGui.SetFont("s14 norm Q5", "Microsoft YaHei")

    ; 动态添加选项按钮，绑定点击事件
    ToolBoxGui.Add("Button", "x20 y+15 w410 h40 Left", " 1. 驼峰命名 (camelCase)").OnEvent("Click", HandleToolAction.Bind(1))
    ToolBoxGui.Add("Button", "x20 y+10 w410 h40 Left", " 2. 下划线命名 (snake_case)").OnEvent("Click", HandleToolAction.Bind(2))
    ToolBoxGui.Add("Button", "x20 y+10 w410 h40 Left", " 3. 转换为纯大写 (UPPERCASE)").OnEvent("Click", HandleToolAction.Bind(3))
    ToolBoxGui.Add("Button", "x20 y+10 w410 h40 Left", " 4. 转换为纯小写 (lowercase)").OnEvent("Click", HandleToolAction.Bind(4))
    ToolBoxGui.Add("Button", "x20 y+10 w410 h40 Left", " 5. 🚀 翻译为英文 (本地 API 接口)").OnEvent("Click", HandleToolAction.Bind(5))

    ; 取消按钮部分同样移除了可能导致冲突的特殊字体标记
    ToolBoxGui.SetFont("s11 c999999 norm", "Microsoft YaHei")
    ToolBoxGui.Add("Button", "x20 y+15 w410 h35 Center", "取消 (或按 Esc 键关闭)").OnEvent("Click", (*) => ToolBoxGui.Destroy())

    ToolBoxGui.OnEvent("Escape", (*) => ToolBoxGui.Destroy())
    ToolBoxGui.Show("Center")
}

; ─── 统一操作处理器 ───
HandleToolAction(ActionType, *)
{
    global SelectedText, ToolBoxGui
    ToolBoxGui.Destroy()

    ResultText := ""

    switch ActionType
    {
        case 1:
            ResultText := ToCamelCase(SelectedText)
        case 2:
            ResultText := ToSnakeCase(SelectedText)
        case 3:
            ResultText := StrUpper(SelectedText)
        case 4:
            ResultText := StrLower(SelectedText)
        case 5:
            ResultText := TranslateToEnglish(SelectedText)
    }

    if (ResultText != "") {
        OldClip := A_Clipboard
        A_Clipboard := ResultText
        Send "^v"
        Sleep 150
        A_Clipboard := OldClip
    }
}

; ─── 文本转换底层函数群 ───
ToCamelCase(str) {
    str := RegExReplace(str, "[\s_-]+", " ")
    words := StrSplit(str, " ")
    outStr := ""
    for idx, word in words {
        if (word == "")
            continue
        if (idx == 1)
            outStr .= StrLower(word)
        else
            outStr .= StrUpper(SubStr(word, 1, 1)) . StrLower(SubStr(word, 2))
    }
    return outStr
}

ToSnakeCase(str) {
    str := RegExReplace(str, "([a-z0-9])([A-Z])", "\$1_\$2")
    str := RegExReplace(str, "[\s-]+", "_")
    return StrLower(RegExReplace(str, "_+", "_"))
}

TranslateToEnglish(textToTranslate) {
    ToolTip "⏳ 正在调用本地接口翻译中..."

    escapedText := RegExReplace(textToTranslate, '"', '\"')
    escapedText := RegExReplace(escapedText, '`n', '\n')
    escapedText := RegExReplace(escapedText, '`r', '\r')
    jsonPayload := '{"q": "' escapedText '", "source": "auto", "target": "en"}'

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "http://127.0.0.1:5000/translate", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)

        responseJSON := whr.ResponseText

        if RegExMatch(responseJSON, '"translatedText"\s*:\s*"([^"]+)"', &match) {
            ToolTip ""
            return RegExReplace(match[1], '\\n', '`n') ; 👈 修复了提取子匹配组的规范
        } else {
            throw Error("无法解析返回的 JSON 字段")
        }
    } catch Error as err {
        ToolTip ""
        MsgBox("❌ 本地翻译 API 调用失败！`n`n原因：请确保 http://127.0.0.1:5000/translate 服务已正常在后台启动。`n`n错误信息: " err.Message, "万能工具箱报错提示", 16)
        return ""
    }
}
