; ==============================================================================
; 功能：Ctrl + Alt + Shift + C 划词百度搜索（纯原生防崩溃版）
; ==============================================================================

^+!c::
{
    ; 1. 备份你原本复制好的剪贴板内容
    OldClipboard := A_Clipboard
    A_Clipboard := ""

    ; 2. 模拟按下 Ctrl+C 复制选中的文字
    Send "^c"

    ; 3. 安全等待剪贴板接收数据（最多等 0.4 秒）
    if ClipWait(0.4)
    {
        ; 4. 用 AHK 内置的 JS 引擎完成 URL 编码，100% 纯原生，绝对不需要加载任何 DLL！
        try {
            js := ComObject("ScriptControl")
            js.Language := "JScript"
            SearchText := js.Run("encodeURIComponent", A_Clipboard)
        } catch {
            ; 如果部分精简版系统缺少组件，则直接使用原文本兜底，确保绝对不崩溃
            SearchText := A_Clipboard
        }

        ; 5. 打开百度搜索
        ; Run "https://www.baidu.com/s?wd=" SearchText
        ; 5. 打开bing.com搜索
        Run "https://www.bing.com/search?q=" SearchText
    }

    ; 6. 还原你原本复制的内容
    Sleep 100
    A_Clipboard := OldClipboard
}
