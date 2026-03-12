/*
  Max 2023 时间工具条 (MaxScript)
  功能：
  1) 可挂载自定义插件/脚本按钮
  2) 支持时间标记与快速调帧
  3) 预留 DIY 脚本槽位

  使用方式：
  - 将本文件拖入 3ds Max 2023 运行，或放到启动脚本目录
  - 点击 “配置插件槽” / “配置DIY槽” 绑定你自己的 .ms/.mcr
*/

global Max2023TimeToolbarState
if Max2023TimeToolbarState == undefined do
(
    Max2023TimeToolbarState =
    (
        dotNetObject "System.Collections.ArrayList"
    )
)

struct MTTB_Config
(
    pluginPaths = #("", "", ""),
    diyPaths = #("", "", "")
)

global Max2023TimeToolbarConfig
if Max2023TimeToolbarConfig == undefined do
(
    Max2023TimeToolbarConfig = MTTB_Config()
)

fn mttb_safeFileName p =
(
    if (p == undefined or p == "") then "未配置"
    else getFilenameFile p
)

fn mttb_runScriptByPath p =
(
    if (p == undefined or p == "") then
    (
        messageBox "该槽位还没有配置脚本。" title:"提示"
        false
    )
    else if (doesFileExist p) then
    (
        fileIn p quiet:true
        true
    )
    else
    (
        messageBox ("文件不存在：\n" + p) title:"错误"
        false
    )
)

fn mttb_updateFrameDisplay lbl =
(
    lbl.text = ("当前帧: " + (sliderTime as integer) as string)
)

try(destroyDialog Max2023TimeToolbar)catch()

rollout Max2023TimeToolbar "Max2023 时间工具条" width:430 height:360
(
    -- 时间调帧
    group "时间调帧"
    (
        spinner spnFrame "跳转到帧:" range:[animationRange.start.frame as integer, animationRange.end.frame as integer, sliderTime.frame as integer] type:#integer fieldwidth:70 align:#left offset:[10,0]
        button btnGoto "跳转" width:80 align:#left offset:[10,-24]
        button btnPrev "-1 帧" width:60 align:#left offset:[110,-24]
        button btnNext "+1 帧" width:60 align:#left offset:[180,-24]
        label lblCurrent "当前帧: 0" align:#left offset:[10,2]
    )

    -- 时间标记
    group "时间标记"
    (
        button btnMark "标记当前帧" width:120 align:#left offset:[10,0]
        button btnClearMark "清空标记" width:90 align:#left offset:[140,-24]
        dropdownlist ddlMarks "已标记帧:" items:#() width:160 align:#left offset:[250,-24]
        button btnGoMark "跳到标记" width:90 align:#left offset:[10,4]
    )

    -- 插件槽位
    group "自定义插件槽"
    (
        button btnPlugin1 "插件槽 1" width:100 align:#left offset:[10,0]
        button btnPlugin2 "插件槽 2" width:100 align:#left offset:[120,-24]
        button btnPlugin3 "插件槽 3" width:100 align:#left offset:[230,-24]
        button btnCfgPlugin "配置插件槽" width:120 align:#left offset:[340,-24]
    )

    -- DIY 槽位
    group "DIY MaxScript 槽"
    (
        button btnDIY1 "DIY 槽 1" width:100 align:#left offset:[10,0]
        button btnDIY2 "DIY 槽 2" width:100 align:#left offset:[120,-24]
        button btnDIY3 "DIY 槽 3" width:100 align:#left offset:[230,-24]
        button btnCfgDIY "配置DIY槽" width:120 align:#left offset:[340,-24]
    )

    fn refreshMarkList =
    (
        local frames = #()
        for i = 0 to (Max2023TimeToolbarState.count - 1) do
        (
            append frames ((Max2023TimeToolbarState.item[i]) as string)
        )
        ddlMarks.items = frames
    )

    fn addFrameMark frameVal =
    (
        local exists = false
        for i = 0 to (Max2023TimeToolbarState.count - 1) while not exists do
        (
            if (Max2023TimeToolbarState.item[i] == frameVal) then exists = true
        )
        if not exists do
        (
            Max2023TimeToolbarState.add frameVal
            -- 简单升序
            for i = 0 to (Max2023TimeToolbarState.count - 2) do
            (
                for j = i + 1 to (Max2023TimeToolbarState.count - 1) do
                (
                    if (Max2023TimeToolbarState.item[i] > Max2023TimeToolbarState.item[j]) then
                    (
                        local t = Max2023TimeToolbarState.item[i]
                        Max2023TimeToolbarState.item[i] = Max2023TimeToolbarState.item[j]
                        Max2023TimeToolbarState.item[j] = t
                    )
                )
            )
        )
        refreshMarkList()
    )

    fn configureSlot pathArray slotName =
    (
        local idxText = getString "输入槽位编号(1-3):" "1"
        if idxText == undefined then return false
        local idx = idxText as integer
        if (idx < 1 or idx > 3) then
        (
            messageBox "请输入 1~3 的编号。" title:"错误"
            return false
        )

        local selected = getOpenFileName caption:("选择 " + slotName + " 脚本") types:"MaxScript(*.ms;*.mcr)|*.ms;*.mcr|All|*.*|"
        if selected != undefined do
        (
            pathArray[idx] = selected
            true
        )
    )

    on Max2023TimeToolbar open do
    (
        mttb_updateFrameDisplay lblCurrent
        spnFrame.range = [animationRange.start.frame as integer, animationRange.end.frame as integer, sliderTime.frame as integer]
        refreshMarkList()

        btnPlugin1.text = "插件1: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[1])
        btnPlugin2.text = "插件2: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[2])
        btnPlugin3.text = "插件3: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[3])

        btnDIY1.text = "DIY1: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[1])
        btnDIY2.text = "DIY2: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[2])
        btnDIY3.text = "DIY3: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[3])
    )

    on btnGoto pressed do
    (
        sliderTime = spnFrame.value
        mttb_updateFrameDisplay lblCurrent
    )

    on btnPrev pressed do
    (
        sliderTime = (sliderTime.frame - 1)
        spnFrame.value = sliderTime.frame
        mttb_updateFrameDisplay lblCurrent
    )

    on btnNext pressed do
    (
        sliderTime = (sliderTime.frame + 1)
        spnFrame.value = sliderTime.frame
        mttb_updateFrameDisplay lblCurrent
    )

    on btnMark pressed do
    (
        addFrameMark sliderTime.frame
    )

    on btnClearMark pressed do
    (
        Max2023TimeToolbarState.Clear()
        refreshMarkList()
    )

    on btnGoMark pressed do
    (
        if ddlMarks.selection > 0 then
        (
            local f = ddlMarks.selected as integer
            sliderTime = f
            spnFrame.value = f
            mttb_updateFrameDisplay lblCurrent
        )
        else
        (
            messageBox "请先选择一个标记帧。" title:"提示"
        )
    )

    on btnCfgPlugin pressed do
    (
        if configureSlot Max2023TimeToolbarConfig.pluginPaths "插件槽" then
        (
            btnPlugin1.text = "插件1: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[1])
            btnPlugin2.text = "插件2: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[2])
            btnPlugin3.text = "插件3: " + (mttb_safeFileName Max2023TimeToolbarConfig.pluginPaths[3])
        )
    )

    on btnCfgDIY pressed do
    (
        if configureSlot Max2023TimeToolbarConfig.diyPaths "DIY槽" then
        (
            btnDIY1.text = "DIY1: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[1])
            btnDIY2.text = "DIY2: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[2])
            btnDIY3.text = "DIY3: " + (mttb_safeFileName Max2023TimeToolbarConfig.diyPaths[3])
        )
    )

    on btnPlugin1 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.pluginPaths[1]
    on btnPlugin2 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.pluginPaths[2]
    on btnPlugin3 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.pluginPaths[3]

    on btnDIY1 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.diyPaths[1]
    on btnDIY2 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.diyPaths[2]
    on btnDIY3 pressed do mttb_runScriptByPath Max2023TimeToolbarConfig.diyPaths[3]
)

createDialog Max2023TimeToolbar style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
