/*
=============================================================================
Max Biped Custom Rig
-----------------------------------------------------------------------------
Builds a custom stretchable bone rig from a selected Biped root.

Rig layout:
  Biped bone -> follow helper -> control space -> animator controller -> rig bone

Notes:
  - Follow helpers stay constrained to the Biped as a reference layer.
  - Controllers use zeroed control spaces so the controller hierarchy behaves like a FK rig.
  - Bones on single-child chains use Bone Auto Align + Stretch.
  - Branch / end bones use controller orientation directly.
=============================================================================
*/

global MBCR_State
global MBCR_Floater

struct MBCR_Item (
    sourceNode,
    shortName = "",
    boneNode = undefined,
    spaceNode = undefined,
    controllerNode = undefined,
    followNode = undefined,
    childCount = 0,
    stretchable = false
)

struct MBCR_StateStruct (
    selectedBiped = undefined,
    rigRoot = undefined,
    helpersGroup = undefined,
    controllersGroup = undefined,
    bonesGroup = undefined,
    items = #()
)

if MBCR_State == undefined do MBCR_State = MBCR_StateStruct()

fn MBCR_IsValidNode obj =
(
    local ok = false
    try (ok = isValidNode obj) catch (ok = false)
    ok
)

fn MBCR_SetStatus msg =
(
    try (MBCR_MainRollout.edtStatus.text = msg) catch ()
)

fn MBCR_UpdateStats =
(
    local boneCount = 0
    local ctrlCount = 0

    for item in MBCR_State.items do
    (
        if MBCR_IsValidNode item.boneNode do boneCount += 1
        if MBCR_IsValidNode item.controllerNode do ctrlCount += 1
    )

    try (MBCR_MainRollout.lblStats.text = ("Bones: " + (boneCount as string) + " | Controllers: " + (ctrlCount as string))) catch ()
)

fn MBCR_ResetState keepBiped:undefined =
(
    if keepBiped != undefined then
        MBCR_State.selectedBiped = keepBiped
    else
    MBCR_State.selectedBiped = undefined
    MBCR_State.rigRoot = undefined
    MBCR_State.helpersGroup = undefined
    MBCR_State.controllersGroup = undefined
    MBCR_State.bonesGroup = undefined
    MBCR_State.items = #()
    MBCR_UpdateStats()
)

fn MBCR_SafeDelete obj =
(
    try
    (
        if MBCR_IsValidNode obj do delete obj
    )
    catch ()
)

fn MBCR_ClearRig silent:true preserveBiped:true =
(
    local savedBiped = undefined
    if preserveBiped and MBCR_IsValidNode MBCR_State.selectedBiped do savedBiped = MBCR_State.selectedBiped

    undo "MBCR Clear Rig" on
    (
        if MBCR_IsValidNode MBCR_State.rigRoot then
        (
            MBCR_SafeDelete MBCR_State.rigRoot
        )
        else
        (
            for item in MBCR_State.items do
            (
                try (MBCR_SafeDelete item.controllerNode) catch ()
                try (MBCR_SafeDelete item.spaceNode) catch ()
                try (MBCR_SafeDelete item.followNode) catch ()
                try (MBCR_SafeDelete item.boneNode) catch ()
                try (MBCR_SafeDelete item.endBoneNode) catch ()
            )

            try
            (
                for endBone in MBCR_State.endBones do MBCR_SafeDelete endBone
            )
            catch ()
        )

        MBCR_ResetState keepBiped:savedBiped

        if not silent do MBCR_SetStatus "Rig deleted."
    )
)

fn MBCR_ResolveBipedRoot obj =
(
    if not MBCR_IsValidNode obj then return undefined

    try
    (
        if (classOf obj.controller) == Vertical_Horizontal_Turn then return obj
    )
    catch ()

    local objectName = ""
    try (objectName = obj.name) catch (objectName = "")
    if objectName == "" then return undefined

    local splitIndex = findString objectName " "
    if splitIndex == undefined then return undefined

    local rootName = substring objectName 1 (splitIndex - 1)
    local rootNode = undefined
    try (rootNode = getNodeByName rootName) catch (rootNode = undefined)

    if MBCR_IsValidNode rootNode then
    (
        try
        (
            if (classOf rootNode.controller) == Vertical_Horizontal_Turn then return rootNode
        )
        catch ()
    )

    undefined
)

fn MBCR_AppendUniqueNode nodeArray nodeValue =
(
    if MBCR_IsValidNode nodeValue then
    (
        if (findItem nodeArray nodeValue) == 0 do append nodeArray nodeValue
    )
)

fn MBCR_GetOptionalBipedBone bipRoot boneSuffix =
(
    local found = undefined
    try (found = getNodeByName (bipRoot.name + " " + boneSuffix)) catch (found = undefined)
    found
)

fn MBCR_NodeDepth nodeValue =
(
    local depth = 0
    local p = undefined
    try (p = nodeValue.parent) catch (p = undefined)

    while MBCR_IsValidNode p do
    (
        depth += 1
        try (p = p.parent) catch (p = undefined)
    )

    depth
)

fn MBCR_SortNodesByDepth nodeArray =
(
    local sorted = #()
    for n in nodeArray do append sorted n

    if sorted.count > 1 then
    (
        for i = 1 to (sorted.count - 1) do
        (
            for j = (i + 1) to sorted.count do
            (
                if (MBCR_NodeDepth sorted[i]) > (MBCR_NodeDepth sorted[j]) then
                (
                    local temp = sorted[i]
                    sorted[i] = sorted[j]
                    sorted[j] = temp
                )
            )
        )
    )

    sorted
)

fn MBCR_GetBipedNodes bipRoot includeFingers:true includeToes:true =
(
    local nodes = #()
    local bipCtrl = undefined
    local pelvisNode = undefined

    try (bipCtrl = bipRoot.controller) catch (bipCtrl = undefined)
    if bipCtrl == undefined then return nodes

    pelvisNode = MBCR_GetOptionalBipedBone bipRoot "Pelvis"
    if MBCR_IsValidNode pelvisNode then
        MBCR_AppendUniqueNode nodes pelvisNode
    else
        try (MBCR_AppendUniqueNode nodes bipCtrl.rootNode) catch ()

    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine1")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine2")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine3")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Neck")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Neck1")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Head")

    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Clavicle")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L UpperArm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Forearm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Hand")

    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Clavicle")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R UpperArm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Forearm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Hand")

    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Thigh")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Calf")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Foot")

    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Thigh")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Calf")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Foot")

    if includeFingers then
    (
        try
        (
            for f = 1 to bipCtrl.leftHand.fingers.count do
            (
                for p = 1 to bipCtrl.leftHand.fingers[f].count do
                (
                    MBCR_AppendUniqueNode nodes bipCtrl.leftHand.fingers[f][p].node
                )
            )
        )
        catch ()

        try
        (
            for f = 1 to bipCtrl.rightHand.fingers.count do
            (
                for p = 1 to bipCtrl.rightHand.fingers[f].count do
                (
                    MBCR_AppendUniqueNode nodes bipCtrl.rightHand.fingers[f][p].node
                )
            )
        )
        catch ()
    )

    if includeToes then
    (
        try
        (
            for t = 1 to bipCtrl.leftFoot.toes.count do
            (
                MBCR_AppendUniqueNode nodes bipCtrl.leftFoot.toes[t].node
            )
        )
        catch ()

        try
        (
            for t = 1 to bipCtrl.rightFoot.toes.count do
            (
                MBCR_AppendUniqueNode nodes bipCtrl.rightFoot.toes[t].node
            )
        )
        catch ()
    )

    MBCR_SortNodesByDepth nodes
)

fn MBCR_GetShortName bipRoot sourceNode =
(
    local shortName = sourceNode.name
    local prefix = bipRoot.name + " "

    if matchPattern shortName pattern:(prefix + "*") then
    (
        shortName = substituteString shortName prefix ""
    )

    shortName = substituteString shortName " " "_"
    shortName = substituteString shortName "-" "_"
    shortName = substituteString shortName ":" "_"
    shortName = substituteString shortName "." "_"
    shortName
)

fn MBCR_GetChildSourceNodes sourceNodes sourceNode =
(
    local children = #()

    for n in sourceNodes where n.parent == sourceNode do append children n

    children
)

fn MBCR_AveragePoint pointArray =
(
    if pointArray.count == 0 then return [0, 0, 0]

    local total = [0, 0, 0]
    for p in pointArray do total += p
    total / pointArray.count
)

fn MBCR_MakeDummy namePrefix sizeValue colorValue =
(
    local d = Dummy name:(uniqueName namePrefix) boxsize:[sizeValue, sizeValue, sizeValue]
    d.wirecolor = colorValue
    d
)

fn MBCR_CreateController shapeName sizeValue colorValue objectName =
(
    local ctrl = undefined

    case shapeName of
    (
        "Point":
        (
            ctrl = Point name:objectName size:sizeValue centermarker:on axistripod:on cross:false box:on
        )
        "Dummy":
        (
            ctrl = Dummy name:objectName boxsize:[sizeValue, sizeValue, sizeValue]
        )
        "Circle":
        (
            ctrl = Circle name:objectName radius:sizeValue steps:24
        )
        "Box":
        (
            ctrl = Box name:objectName length:(sizeValue * 1.5) width:(sizeValue * 1.5) height:(sizeValue * 1.5)
        )
        "Diamond":
        (
            local pts = #([0, sizeValue, 0], [sizeValue, 0, 0], [0, -sizeValue, 0], [-sizeValue, 0, 0], [0, sizeValue, 0])
            ctrl = SplineShape name:objectName
            addNewSpline ctrl
            for p in pts do addKnot ctrl 1 #corner #line p
            updateShape ctrl
        )
        default:
        (
            ctrl = Point name:objectName size:sizeValue centermarker:on axistripod:on cross:false box:on
        )
    )

    if ctrl != undefined do ctrl.wirecolor = colorValue
    ctrl
)

fn MBCR_AddPositionConstraint targetNode sourceNode weight:100.0 =
(
    local con = undefined
    try
    (
        con = Position_Constraint()
        targetNode.pos.controller = con
        con.appendTarget sourceNode weight
    )
    catch (con = undefined)
    con
)

fn MBCR_AddOrientationConstraint targetNode sourceNode weight:100.0 =
(
    local con = undefined
    try
    (
        con = Orientation_Constraint()
        targetNode.rotation.controller = con
        con.appendTarget sourceNode weight
    )
    catch (con = undefined)
    con
)

fn MBCR_GetBoneEndPosition sourceNodes sourceNode fallbackLength branchLength =
(
    local startPos = sourceNode.transform.pos
    local children = MBCR_GetChildSourceNodes sourceNodes sourceNode

    if children.count == 1 then
    (
        local oneChildPos = children[1].transform.pos
        if (distance startPos oneChildPos) > 0.001 then return oneChildPos
    )

    if children.count > 1 then
    (
        local dirSum = [0, 0, 0]

        for c in children do
        (
            local childDir = c.transform.pos - startPos
            if (length childDir) > 0.001 do dirSum += (normalize childDir)
        )

        if (length dirSum) < 0.001 do dirSum = sourceNode.transform.row1
        if (length dirSum) < 0.001 do dirSum = [1, 0, 0]

        dirSum = normalize dirSum
        return (startPos + (dirSum * branchLength))
    )

    local direction = [0, 0, 0]

    if MBCR_IsValidNode sourceNode.parent then
    (
        direction = startPos - sourceNode.parent.transform.pos
    )

    if (length direction) < 0.001 do direction = sourceNode.transform.row1
    if (length direction) < 0.001 do direction = [fallbackLength, 0, 0]

    direction = normalize direction
    startPos + (direction * fallbackLength)
)

fn MBCR_CreateBoneForSource bipRoot sourceNode sourceNodes boneWidth ctrlSize =
(
    local startPos = sourceNode.transform.pos
    local fallbackLength = boneWidth * 8.0
    local branchLength = boneWidth * 3.0
    local ctrlFallbackLength = ctrlSize * 1.5
    if ctrlFallbackLength > fallbackLength do fallbackLength = ctrlFallbackLength
    if fallbackLength < 2.0 do fallbackLength = 2.0
    if branchLength < (boneWidth * 1.5) do branchLength = boneWidth * 1.5

    local endPos = MBCR_GetBoneEndPosition sourceNodes sourceNode fallbackLength branchLength
    if (distance startPos endPos) < 0.001 do endPos = startPos + [fallbackLength, 0, 0]

    local upVec = sourceNode.transform.row3
    if (length upVec) < 0.001 do upVec = [0, 0, 1]

    local boneName = uniqueName ("MBCR_Bone_" + (MBCR_GetShortName bipRoot sourceNode))
    local newBone = BoneSys.createBone startPos endPos upVec

    newBone.name = boneName
    newBone.width = boneWidth
    newBone.height = boneWidth
    newBone.showLinks = true
    newBone.wirecolor = (color 0 255 120)

    try (newBone.boneEnable = true) catch ()
    try (newBone.boneAxis = #X) catch ()

    newBone
)

fn MBCR_CreateRigGroups bipRoot ctrlSize =
(
    local rootSize = ctrlSize * 0.6
    if rootSize < 5.0 do rootSize = 5.0

    local rigRoot = MBCR_MakeDummy ("MBCR_" + bipRoot.name + "_RIG") rootSize (color 255 180 0)
    local helpersGrp = MBCR_MakeDummy "MBCR_Follow_GRP" (rootSize * 0.8) (color 0 220 255)
    local ctrlsGrp = MBCR_MakeDummy "MBCR_Controllers_GRP" (rootSize * 0.8) (color 255 210 0)
    local bonesGrp = MBCR_MakeDummy "MBCR_Bones_GRP" (rootSize * 0.8) (color 0 255 120)

    rigRoot.transform = bipRoot.transform
    helpersGrp.transform = rigRoot.transform
    ctrlsGrp.transform = rigRoot.transform
    bonesGrp.transform = rigRoot.transform

    helpersGrp.parent = rigRoot
    ctrlsGrp.parent = rigRoot
    bonesGrp.parent = rigRoot

    helpersGrp.isFrozen = true
    rigRoot.boxmode = true
    rigRoot.wirecolor = (color 255 180 0)

    MBCR_State.rigRoot = rigRoot
    MBCR_State.helpersGroup = helpersGrp
    MBCR_State.controllersGroup = ctrlsGrp
    MBCR_State.bonesGroup = bonesGrp
)

fn MBCR_CreateItemForSource bipRoot sourceNode sourceNodes ctrlShape ctrlSize ctrlColor boneWidth =
(
    local item = MBCR_Item()
    item.sourceNode = sourceNode
    item.shortName = MBCR_GetShortName bipRoot sourceNode

    local children = MBCR_GetChildSourceNodes sourceNodes sourceNode
    item.childCount = children.count

    local followSize = ctrlSize * 0.35
    if followSize < 2.0 do followSize = 2.0
    local followName = uniqueName ("MBCR_Follow_" + item.shortName)
    local followNode = Point name:followName size:followSize centermarker:off axistripod:off cross:false box:on
    followNode.transform = sourceNode.transform
    followNode.wirecolor = (color 0 220 255)
    followNode.parent = MBCR_State.helpersGroup
    followNode.isFrozen = true
    try (followNode.isHidden = true) catch ()

    MBCR_AddPositionConstraint followNode sourceNode weight:100.0
    MBCR_AddOrientationConstraint followNode sourceNode weight:100.0

    local spaceSize = ctrlSize * 0.45
    if spaceSize < 3.0 do spaceSize = 3.0
    local spaceName = uniqueName ("MBCR_Space_" + item.shortName)
    local spaceNode = Point name:spaceName size:spaceSize centermarker:off axistripod:off cross:false box:on
    spaceNode.transform = sourceNode.transform
    spaceNode.wirecolor = ctrlColor
    spaceNode.parent = MBCR_State.controllersGroup
    spaceNode.isFrozen = true
    try (spaceNode.isHidden = true) catch ()

    local ctrlName = uniqueName ("MBCR_CTRL_" + item.shortName)
    local ctrlNode = MBCR_CreateController ctrlShape ctrlSize ctrlColor ctrlName
    ctrlNode.transform = sourceNode.transform
    ctrlNode.parent = spaceNode
    ctrlNode.transform = sourceNode.transform

    local boneNode = MBCR_CreateBoneForSource bipRoot sourceNode sourceNodes boneWidth ctrlSize

    item.followNode = followNode
    item.spaceNode = spaceNode
    item.controllerNode = ctrlNode
    item.boneNode = boneNode
    item.stretchable = (children.count == 1)
    item
)

fn MBCR_ApplyBoneLinks sourceNodes itemsArray =
(
    for i = 1 to itemsArray.count do
    (
        local sourceParent = undefined
        try (sourceParent = itemsArray[i].sourceNode.parent) catch (sourceParent = undefined)

        local parentIndex = findItem sourceNodes sourceParent
        if parentIndex > 0 then
        (
            try (itemsArray[i].boneNode.parent = itemsArray[parentIndex].boneNode) catch ()
        )
        else
        (
            try (itemsArray[i].boneNode.parent = MBCR_State.bonesGroup) catch ()
        )
    )
)

fn MBCR_ApplyFollowLinks sourceNodes itemsArray =
(
    for i = 1 to itemsArray.count do
    (
        local sourceParent = undefined
        try (sourceParent = itemsArray[i].sourceNode.parent) catch (sourceParent = undefined)

        local parentIndex = findItem sourceNodes sourceParent
        if parentIndex > 0 then
        (
            try (itemsArray[i].followNode.parent = itemsArray[parentIndex].followNode) catch ()
        )
        else
        (
            try (itemsArray[i].followNode.parent = MBCR_State.helpersGroup) catch ()
        )
    )
)

fn MBCR_ApplyControllerLinks sourceNodes itemsArray =
(
    for i = 1 to itemsArray.count do
    (
        local sourceParent = undefined
        try (sourceParent = itemsArray[i].sourceNode.parent) catch (sourceParent = undefined)

        local parentIndex = findItem sourceNodes sourceParent
        if parentIndex > 0 then
        (
            try (itemsArray[i].spaceNode.parent = itemsArray[parentIndex].controllerNode) catch ()
            try (itemsArray[i].spaceNode.transform = itemsArray[i].followNode.transform) catch ()
        )
        else
        (
            try (itemsArray[i].spaceNode.parent = MBCR_State.controllersGroup) catch ()
            try (itemsArray[i].spaceNode.transform = itemsArray[i].followNode.transform) catch ()
            MBCR_AddPositionConstraint itemsArray[i].spaceNode itemsArray[i].followNode weight:100.0
            MBCR_AddOrientationConstraint itemsArray[i].spaceNode itemsArray[i].followNode weight:100.0
        )

        try (itemsArray[i].controllerNode.parent = itemsArray[i].spaceNode) catch ()
        try (itemsArray[i].controllerNode.transform = itemsArray[i].spaceNode.transform) catch ()
    )
)

fn MBCR_ApplyBoneControllers itemsArray enableStretch =
(
    for item in itemsArray do
    (
        if MBCR_IsValidNode item.boneNode and MBCR_IsValidNode item.controllerNode then
        (
            MBCR_AddPositionConstraint item.boneNode item.controllerNode weight:100.0
            MBCR_AddOrientationConstraint item.boneNode item.controllerNode weight:100.0

            if enableStretch and item.stretchable then
            (
                try (item.boneNode.boneAutoAlign = true) catch ()
                try (item.boneNode.boneFreezeLength = false) catch ()
                try (item.boneNode.boneScaleType = #scale) catch ()
                try (item.boneNode.realignBoneToChild()) catch ()
                try (item.boneNode.resetBoneStretch()) catch ()
            )
            else
            (
                try (item.boneNode.boneAutoAlign = false) catch ()
                try (item.boneNode.boneFreezeLength = true) catch ()
            )
        )
    )
)

fn MBCR_SelectControllers =
(
    local nodes = #()
    for item in MBCR_State.items do if MBCR_IsValidNode item.controllerNode do append nodes item.controllerNode
    if nodes.count > 0 then select nodes
    nodes.count
)

fn MBCR_SelectBones =
(
    local nodes = #()
    for item in MBCR_State.items do if MBCR_IsValidNode item.boneNode do append nodes item.boneNode
    if nodes.count > 0 then select nodes
    nodes.count
)

fn MBCR_BuildRig bipRoot includeFingers:true includeToes:true ctrlShape:"Circle" ctrlSize:12.0 ctrlColor:(color 255 210 0) boneWidth:2.5 enableStretch:true =
(
    if not MBCR_IsValidNode bipRoot then
    (
        MBCR_SetStatus "No valid Biped root selected."
        return false
    )

    local sourceNodes = MBCR_GetBipedNodes bipRoot includeFingers:includeFingers includeToes:includeToes
    if sourceNodes.count == 0 then
    (
        MBCR_SetStatus "No Biped nodes were collected."
        return false
    )

    undo "MBCR Build Rig" on
    (
        MBCR_ClearRig silent:true preserveBiped:true
        MBCR_State.selectedBiped = bipRoot

        MBCR_CreateRigGroups bipRoot ctrlSize

        local itemsArray = #()

        for sourceNode in sourceNodes do
        (
            append itemsArray (MBCR_CreateItemForSource bipRoot sourceNode sourceNodes ctrlShape ctrlSize ctrlColor boneWidth)
        )

        MBCR_State.items = itemsArray
        MBCR_ApplyFollowLinks sourceNodes MBCR_State.items
        MBCR_ApplyControllerLinks sourceNodes MBCR_State.items
        MBCR_ApplyBoneLinks sourceNodes MBCR_State.items
        MBCR_ApplyBoneControllers MBCR_State.items enableStretch

        MBCR_UpdateStats()
        MBCR_SelectControllers()

        local stretchCount = 0
        for item in MBCR_State.items where item.stretchable do stretchCount += 1

        MBCR_SetStatus (
            "Rig build complete." + "\n" +
            "Biped: " + bipRoot.name + "\n" +
            "Nodes: " + (sourceNodes.count as string) + "\n" +
            "Stretch chains: " + (stretchCount as string) + "\n" +
            "Rig root: " + MBCR_State.rigRoot.name
        )
    )

    true
)

rollout MBCR_MainRollout "Max Biped Custom Rig" width:360 height:430
(
    group "Biped"
    (
        pickbutton btnPickBiped "Pick Biped Root" width:320 height:32
        label lblBipedInfo "Selected: None" align:#left
    )

    group "Build Options"
    (
        checkbox chkFingers "Include fingers" checked:true across:2
        checkbox chkToes "Include toes" checked:true
        checkbox chkStretch "Enable stretch on single-child chains" checked:true

        dropdownlist ddlCtrlShape "Controller shape" items:#("Circle", "Point", "Dummy", "Box", "Diamond") selection:1 width:320
        spinner spnCtrlSize "Controller size" range:[1,100,12] type:#float width:320
        spinner spnBoneWidth "Bone width" range:[0.1,20,2.5] type:#float width:320
        colorpicker cpCtrlColor "Controller color" color:(color 255 210 0) width:320
    )

    group "Actions"
    (
        button btnBuild "Build Stretch Rig" width:320 height:40
        button btnClear "Clear Rig" width:320 height:28
        button btnSelectCtrls "Select Controllers" width:155 height:28 across:2
        button btnSelectBones "Select Bones" width:155 height:28
        label lblStats "Bones: 0 | Controllers: 0" align:#left
    )

    group "Status"
    (
        edittext edtStatus "" width:320 height:120 readOnly:true
    )

    on btnPickBiped picked obj do
    (
        local resolved = MBCR_ResolveBipedRoot obj

        if MBCR_IsValidNode resolved then
        (
            MBCR_State.selectedBiped = resolved
            lblBipedInfo.text = ("Selected: " + resolved.name)
            MBCR_SetStatus ("Biped root ready: " + resolved.name)
        )
        else
        (
            MBCR_State.selectedBiped = undefined
            lblBipedInfo.text = "Selected: None"
            messageBox "Please pick a Biped root or any Biped bone from the same character." title:"Invalid Biped"
            MBCR_SetStatus "Invalid selection."
        )
    )

    on btnBuild pressed do
    (
        if not MBCR_IsValidNode MBCR_State.selectedBiped then
        (
            messageBox "Pick a Biped root first." title:"No Biped"
            return false
        )

        if MBCR_IsValidNode MBCR_State.rigRoot then
        (
            if not (queryBox "A generated rig already exists. Rebuild and replace it?") then return false
        )

        local ok = MBCR_BuildRig MBCR_State.selectedBiped \
            includeFingers:chkFingers.checked \
            includeToes:chkToes.checked \
            ctrlShape:ddlCtrlShape.selected \
            ctrlSize:spnCtrlSize.value \
            ctrlColor:cpCtrlColor.color \
            boneWidth:spnBoneWidth.value \
            enableStretch:chkStretch.checked

        if ok then
        (
            messageBox "Custom Biped rig created." title:"Build Complete"
        )
        else
        (
            messageBox "Build failed. Check the Listener and status box." title:"Build Failed"
        )
    )

    on btnClear pressed do
    (
        if MBCR_IsValidNode MBCR_State.rigRoot then
        (
            if queryBox "Delete the current generated rig?" then
            (
                MBCR_ClearRig silent:false preserveBiped:true
                lblBipedInfo.text = if MBCR_IsValidNode MBCR_State.selectedBiped then ("Selected: " + MBCR_State.selectedBiped.name) else "Selected: None"
            )
        )
        else
        (
            MBCR_SetStatus "No generated rig to delete."
        )
    )

    on btnSelectCtrls pressed do
    (
        local count = MBCR_SelectControllers()
        MBCR_SetStatus ("Selected controllers: " + (count as string))
    )

    on btnSelectBones pressed do
    (
        local count = MBCR_SelectBones()
        MBCR_SetStatus ("Selected bones: " + (count as string))
    )
)

fn MBCR_OpenUI =
(
    try (closeRolloutFloater MBCR_Floater) catch ()
    MBCR_Floater = newRolloutFloater "Max Biped Custom Rig" 380 470
    addRollout MBCR_MainRollout MBCR_Floater
    MBCR_UpdateStats()
    if MBCR_IsValidNode MBCR_State.selectedBiped then
    (
        try (MBCR_MainRollout.lblBipedInfo.text = ("Selected: " + MBCR_State.selectedBiped.name)) catch ()
    )
)

macroScript MaxBipedCustomRig
category:"Animation Tools"
tooltip:"Max Biped Custom Rig"
buttonText:"Biped Rig"
(
    MBCR_OpenUI()
)

MBCR_OpenUI()
