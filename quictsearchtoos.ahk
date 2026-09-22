; ==============================================================================
; 功能：Ctrl + Alt + Shift + T 文本万能工具箱（一行 2 列紧凑排列版）
; 特点：大字菜单预览，双列并排节省空间，集成常见文本格式化与本地翻译接口
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

    ; 2. 构建高颜值双列布局窗口
    ToolBoxGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "文本万能工具箱")
    ToolBoxGui.BackColor := "FDFDFD"

    ; 头部提示（加宽至 520 像素，适应双列布局）
    ToolBoxGui.SetFont("s13 Bold Q5", "Microsoft YaHei")
    ToolBoxGui.Add("Text", "w500 c666666 x20 y15", "🛠️ 文本万能工具箱")
    ToolBoxGui.Add("Text", "w500 cCCCCCC x20 y+2", "----------------------------------------------------------------------------------")

    ; 📐 设置按钮字体：13号微软雅黑（稍作微调以适应并排）
    ToolBoxGui.SetFont("s13 norm Q5", "Microsoft YaHei")

    ; ─── 🚀 【核心优化：双列栅格化布局】 ───
    ; 第一行：1.驼峰 (左)  |  2.下划线 (右)
    ToolBoxGui.Add("Button", "x20 y+15 w240 h42 Left", " 1. 驼峰命名 (camelCase)").OnEvent("Click", HandleToolAction.Bind(1))
    ToolBoxGui.Add("Button", "x270 yp w240 h42 Left", " 2. 下划线命名 (snake_case)").OnEvent("Click", HandleToolAction.Bind(2))

    ; 第二行：3.纯大写 (左)  |  4.纯小写 (右)
    ToolBoxGui.Add("Button", "x20 y+10 w240 h42 Left", " 3. 转换为纯大写 (UPPER)").OnEvent("Click", HandleToolAction.Bind(3))
    ToolBoxGui.Add("Button", "x270 yp w240 h42 Left", " 4. 转换为纯小写 (lower)").OnEvent("Click", HandleToolAction.Bind(4))

    ; 第三行：5.翻译为英文 (左)  |  6.翻译为中文 (右)
    ToolBoxGui.Add("Button", "x20 y+10 w240 h42 Left", " 5. 中文➡️英文").OnEvent("Click", HandleToolAction.Bind(5))
    ToolBoxGui.Add("Button", "x270 yp w240 h42 Left", " 6. 英文➡️中文").OnEvent("Click", HandleToolAction.Bind(6))

    ; 第四行：取消/关闭按钮
    ToolBoxGui.SetFont("s11 c999999 norm", "Microsoft YaHei")
    ToolBoxGui.Add("Button", "x20 y+12 w490 h35 Center", "取消 (或按 Esc 键关闭)").OnEvent("Click", (*) => ToolBoxGui.Destroy())
    ; ──────────────────────────────────────

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
            ResultText := TranslateTo(SelectedText, "zh-Hans", "en")
        case 6:
            ResultText := TranslateTo(SelectedText, "en", "zh-Hans")
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
    ; 按行转换并保留原有的换行符（\r\n 或 \n）
    lineSep := InStr(str, "`r`n") ? "`r`n" : "`n"
    lines := StrSplit(StrReplace(str, "`r", ""), "`n")
    outStr := ""
    for index, line in lines {
        if (index > 1)
            outStr .= lineSep
        words := StrSplit(RegExReplace(line, "[\s_-]+", " "), " ")
        for idx, word in words {
            if (word == "")
                continue
            if (idx == 1)
                outStr .= StrLower(word)
            else
                outStr .= StrUpper(SubStr(word, 1, 1)) . StrLower(SubStr(word, 2))
        }
    }
    return outStr
}

ToSnakeCase(str) {
    ; 按行转换并保留原有的换行符（\r\n 或 \n）
    lineSep := InStr(str, "`r`n") ? "`r`n" : "`n"
    lines := StrSplit(StrReplace(str, "`r", ""), "`n")
    outStr := ""
    for index, line in lines {
        if (index > 1)
            outStr .= lineSep
        text := RegExReplace(line, "([a-z0-9])([A-Z])", "\$1_\$2")
        text := RegExReplace(text, "[\s-]+", "_")
        outStr .= StrLower(RegExReplace(text, "_+", "_"))
    }
    return outStr
}

TranslateTo(textToTranslate, source, targetLang) {
    ToolTip "⏳ 正在调用本地接口翻译中..."

    escapedText := RegExReplace(textToTranslate, '"', '\"')
    escapedText := RegExReplace(escapedText, '`n', '\n')
    escapedText := RegExReplace(escapedText, '`r', '\r')
    jsonPayload := '{"q": "' escapedText '", "source": "' source '", "target": "' targetLang '"}'

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", "http://127.0.0.1:5000/translate", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(jsonPayload)

        ; 直接用原始字节并按 UTF-8 解码，避免 ResponseText 按错误编码解出乱码
        arr := whr.ResponseBody
        pData := NumGet(ComObjValue(arr) + 8 + A_PtrSize, "Ptr")
        responseJSON := StrGet(pData, arr.MaxIndex() + 1, "UTF-8")

        ; 提取匹配组中的第一个值（即翻译后的文本）
        if RegExMatch(responseJSON, '"translatedText"\s*:\s*"([^"]+)"', &match) {
            ToolTip ""
            return RegExReplace(match[1], '\\n', '`n') ; 👈 修正： match[1] 才能正确读取括号内的文本
        } else {
            throw Error("无法解析返回的 JSON 字段")
        }
    } catch Error as err {
        ToolTip ""
        MsgBox("❌ 本地翻译 API 调用失败！`n`n原因：请确保 http://127.0.0.1:5000/translate 服务已正常在后台启动。`n`n错误信息: " err.Message, "万能工具箱报错提示", 16)
        return ""
    }
}
