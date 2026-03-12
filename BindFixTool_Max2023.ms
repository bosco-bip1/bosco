/*
  BindFixTool_Max2023.ms
  3ds Max 2023 绑定修型辅助工具

  功能：
  1) 选择绑定模型（通常带 Skin）
  2) 从当前姿态快速创建修型目标（快照）
  3) 自动写入 Morpher 指定通道
  4) 可一键将该通道权重置为 100（便于立刻检查）

  使用建议：
  - 在骨骼摆到问题姿态时执行“创建修型并写入通道”
  - 进入生成的修型模型上进行点级编辑
  - 通过 Morpher 通道权重测试修型效果
*/

try(destroyDialog BindFixTool_RL)catch()

struct BindFixState
(
    meshNode,
    lastTarget
)

global g_bindFixState = BindFixState meshNode:undefined lastTarget:undefined

fn bf_isValidMeshNode n =
(
    isValidNode n and superclassof n == GeometryClass
)

fn bf_hasMorpher n =
(
    if not bf_isValidMeshNode n then return undefined
    for m in n.modifiers do
    (
        if classof m == Morpher do return m
    )
    undefined
)

fn bf_getOrCreateMorpher n =
(
    local morpherMod = bf_hasMorpher n
    if morpherMod == undefined do
    (
        morpherMod = Morpher()
        addModifier n morpherMod
    )
    morpherMod
)

fn bf_buildName srcNode ch =
(
    local t = formattedPrint currentTime format:"04d"
    srcNode.name + "_Corr_F" + t + "_CH" + (formattedPrint ch format:"02d")
)

fn bf_snapshotToNode srcNode targetName =
(
    local msh = snapshotAsMesh srcNode
    local newNode = mesh mesh:msh name:targetName
    convertToPoly newNode
    newNode.wirecolor = yellow
    newNode
)

fn bf_addToMorpher srcNode targetNode ch =
(
    local morpherMod = bf_getOrCreateMorpher srcNode
    local success = WM3_MC_BuildFromNode morpherMod ch targetNode
    if success then
    (
        WM3_MC_SetValue morpherMod ch 100.0
        true
    )
    else false
)

rollout BindFixTool_RL "Bind Fix Tool - Max2023" width:320
(
    groupBox gp1 "1) 绑定模型" pos:[8,8] width:304 height:86
    pickButton pb_pickMesh "拾取模型" pos:[20,34] width:130 height:28 autoDisplay:true filter:bf_isValidMeshNode
    label lb_mesh "当前：未选择" pos:[20,68] width:270 height:16

    groupBox gp2 "2) 修型写入" pos:[8,102] width:304 height:126
    spinner sp_channel "Morpher 通道:" pos:[20,128] width:130 range:[1,100,1] type:#integer
    checkbox cb_hideTarget "创建后隐藏修型模型" pos:[160,130] width:140 checked:true
    button bt_makeCorr "创建修型并写入通道" pos:[20,158] width:270 height:30
    button bt_selectLast "选中上次创建修型" pos:[20,194] width:130 height:24
    button bt_set100 "当前通道设为100" pos:[160,194] width:130 height:24

    groupBox gp3 "3) 状态" pos:[8,234] width:304 height:84
    label lb_state "就绪。" pos:[20,258] width:270 height:42

    fn setState msg =
    (
        lb_state.text = msg
        format "[BindFixTool] %\n" msg
    )

    on pb_pickMesh picked obj do
    (
        g_bindFixState.meshNode = obj
        lb_mesh.text = "当前：" + obj.name
        setState ("已选择模型：" + obj.name)
    )

    on bt_makeCorr pressed do
    (
        local src = g_bindFixState.meshNode
        if not bf_isValidMeshNode src then
        (
            messageBox "请先拾取一个有效几何体模型。" title:"Bind Fix Tool"
            setState "失败：未选择有效模型。"
            return()
        )

        local ch = sp_channel.value
        local targetName = bf_buildName src ch
        local targetNode = bf_snapshotToNode src targetName

        if targetNode == undefined then
        (
            setState "失败：无法创建修型快照。"
            return()
        )

        local ok = bf_addToMorpher src targetNode ch
        if not ok then
        (
            delete targetNode
            messageBox "写入 Morpher 失败。请确认通道可用且模型拓扑一致。" title:"Bind Fix Tool"
            setState "失败：写入 Morpher 失败。"
            return()
        )

        if cb_hideTarget.checked do targetNode.isHidden = true
        g_bindFixState.lastTarget = targetNode

        setState ("成功：已创建 " + targetNode.name + " 并写入 CH" + ch as string)
    )

    on bt_selectLast pressed do
    (
        if isValidNode g_bindFixState.lastTarget then
        (
            select g_bindFixState.lastTarget
            max modify mode
            setState ("已选中：" + g_bindFixState.lastTarget.name)
        )
        else
        (
            setState "没有可选中的修型目标。"
        )
    )

    on bt_set100 pressed do
    (
        local src = g_bindFixState.meshNode
        if not bf_isValidMeshNode src then
        (
            setState "失败：请先选择模型。"
            return()
        )

        local morpherMod = bf_hasMorpher src
        if morpherMod == undefined then
        (
            setState "失败：模型没有 Morpher。"
            return()
        )

        local ch = sp_channel.value
        WM3_MC_SetValue morpherMod ch 100.0
        setState ("已将 CH" + ch as string + " 设置为 100。")
    )
)

createDialog BindFixTool_RL style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
