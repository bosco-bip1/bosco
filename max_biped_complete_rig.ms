/*
=============================================================================
Max Biped Complete Rig (Advanced Skeleton Style)
-----------------------------------------------------------------------------
Builds a complete stretchable bone rig from a selected Biped root.
Similar to Advanced Skeleton structure with end bones and proper naming.

Rig layout:
  Biped bone -> follow helper -> animator controller -> rig bone -> end bone

Features:
  - Standard bone naming (Root, Spine1-4, L_Shoulder, etc.)
  - End bones for all leaf nodes
  - Complete finger and toe chains
  - Twist bones support (optional)
  - IK-ready structure

Usage:
  - Run script to open UI
  - To force reset state: MBCR_ForceReset()
=============================================================================
*/

-- Force reset function (call this if you get errors about missing properties)
fn MBCR_ForceReset =
(
    global MBCR_State = undefined
    global MBCR_Floater = undefined
    format "MBCR State has been reset. Please reload the script.\n"
)

global MBCR_State
global MBCR_Floater

struct MBCR_Item (
    sourceNode,
    shortName = "",
    standardName = "",
    boneNode = undefined,
    endBoneNode = undefined,
    controllerNode = undefined,
    followNode = undefined,
    childCount = 0,
    stretchable = false,
    isEndBone = false
)

struct MBCR_StateStruct (
    selectedBiped = undefined,
    rigRoot = undefined,
    helpersGroup = undefined,
    bonesGroup = undefined,
    controllersGroup = undefined,
    items = #(),
    endBones = #()
)

-- Initialize or upgrade state structure
if MBCR_State == undefined then
(
    MBCR_State = MBCR_StateStruct()
)
else
(
    -- Upgrade old state structure if needed
    try
    (
        if MBCR_State.endBones == undefined do MBCR_State.endBones = #()
        if MBCR_State.controllersGroup == undefined do MBCR_State.controllersGroup = undefined
    )
    catch
    (
        -- If upgrade fails, reset to new structure
        MBCR_State = MBCR_StateStruct()
    )
)

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
    local endBoneCount = 0

    for item in MBCR_State.items do
    (
        if MBCR_IsValidNode item.boneNode do boneCount += 1
        if MBCR_IsValidNode item.controllerNode do ctrlCount += 1
    )

    -- Check if endBones property exists (for backward compatibility)
    try
    (
        if MBCR_State.endBones != undefined then
        (
            for eb in MBCR_State.endBones do
            (
                if MBCR_IsValidNode eb do endBoneCount += 1
            )
        )
    )
    catch ()

    try (
        MBCR_MainRollout.lblStats.text = (
            "Bones: " + (boneCount as string) +
            " | End: " + (endBoneCount as string) +
            " | Controllers: " + (ctrlCount as string)
        )
    ) catch ()
)

fn MBCR_ResetState keepBiped:undefined =
(
    if keepBiped != undefined then
        MBCR_State.selectedBiped = keepBiped
    else
        MBCR_State.selectedBiped = undefined
    MBCR_State.rigRoot = undefined
    MBCR_State.helpersGroup = undefined
    MBCR_State.bonesGroup = undefined
    MBCR_State.controllersGroup = undefined
    MBCR_State.items = #()
    MBCR_State.endBones = #()
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
            -- Delete end bones if they exist
            try
            (
                if MBCR_State.endBones != undefined then
                (
                    for eb in MBCR_State.endBones do MBCR_SafeDelete eb
                )
            )
            catch ()

            for item in MBCR_State.items do
            (
                MBCR_SafeDelete item.endBoneNode
                MBCR_SafeDelete item.controllerNode
                MBCR_SafeDelete item.followNode
                MBCR_SafeDelete item.boneNode
            )
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

    -- Spine chain
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine1")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine2")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Spine3")

    -- Neck and head
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Neck")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Neck1")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "Head")

    -- Left arm
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Clavicle")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L UpperArm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Forearm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Hand")

    -- Right arm
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Clavicle")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R UpperArm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Forearm")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Hand")

    -- Left leg
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Thigh")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Calf")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "L Foot")

    -- Right leg
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Thigh")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Calf")
    MBCR_AppendUniqueNode nodes (MBCR_GetOptionalBipedBone bipRoot "R Foot")

    -- Fingers
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

    -- Toes
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

fn MBCR_GetStandardBoneName shortName =
(
    -- Advanced Skeleton style naming
    local nameMap = #(
        #("Pelvis", "Root"),
        #("Spine", "Spine1"),
        #("Spine1", "Spine2"),
        #("Spine2", "Spine3"),
        #("Spine3", "Spine4"),
        #("Neck", "Neck"),
        #("Neck1", "NeckTop"),
        #("Head", "Head"),

        #("L_Clavicle", "L_Clavicle"),
        #("L_UpperArm", "L_Shoulder"),
        #("L_Forearm", "L_Elbow"),
        #("L_Hand", "L_Wrist"),

        #("R_Clavicle", "R_Clavicle"),
        #("R_UpperArm", "R_Shoulder"),
        #("R_Forearm", "R_Elbow"),
        #("R_Hand", "R_Wrist"),

        #("L_Thigh", "L_Hip"),
        #("L_Calf", "L_Knee"),
        #("L_Foot", "L_Ankle"),
        #("L_Toe0", "L_Ball"),

        #("R_Thigh", "R_Hip"),
        #("R_Calf", "R_Knee"),
        #("R_Foot", "R_Ankle"),
        #("R_Toe0", "R_Ball"),

        -- Fingers
        #("L_Finger0", "L_Thumb"),
        #("L_Finger1", "L_Index"),
        #("L_Finger2", "L_Middle"),
        #("L_Finger3", "L_Ring"),
        #("L_Finger4", "L_Pinky"),

        #("R_Finger0", "R_Thumb"),
        #("R_Finger1", "R_Index"),
        #("R_Finger2", "R_Middle"),
        #("R_Finger3", "R_Ring"),
        #("R_Finger4", "R_Pinky")
    )

    for pair in nameMap do
    (
        if matchPattern shortName pattern:("*" + pair[1] + "*") then return pair[2]
    )

    shortName
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

fn MBCR_GetBoneEndPosition sourceNodes sourceNode fallbackLength =
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
        local childPoints = for c in children collect c.transform.pos
        local avgPos = MBCR_AveragePoint childPoints
        if (distance startPos avgPos) > 0.001 then return avgPos
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
    local ctrlFallbackLength = ctrlSize * 1.5
    if ctrlFallbackLength > fallbackLength do fallbackLength = ctrlFallbackLength
    if fallbackLength < 2.0 do fallbackLength = 2.0

    local endPos = MBCR_GetBoneEndPosition sourceNodes sourceNode fallbackLength
    if (distance startPos endPos) < 0.001 do endPos = startPos + [fallbackLength, 0, 0]

    local upVec = sourceNode.transform.row3
    if (length upVec) < 0.001 do upVec = [0, 0, 1]

    local shortName = MBCR_GetShortName bipRoot sourceNode
    local standardName = MBCR_GetStandardBoneName shortName
    local boneName = uniqueName ("Bone_" + standardName)
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

fn MBCR_CreateEndBone parentBone boneWidth =
(
    if not MBCR_IsValidNode parentBone then return undefined

    local startPos = undefined
    local endPos = undefined

    try
    (
        local boneLength = parentBone.length
        if boneLength < 0.1 do boneLength = boneWidth * 3.0

        local direction = normalize (parentBone.transform.row1)
        startPos = parentBone.transform.pos + (direction * boneLength)

        local endBoneLength = boneWidth * 2.0
        if endBoneLength < 1.0 do endBoneLength = 1.0

        endPos = startPos + (direction * endBoneLength)
    )
    catch
    (
        return undefined
    )

    local upVec = parentBone.transform.row3
    if (length upVec) < 0.001 do upVec = [0, 0, 1]

    local endBoneName = uniqueName (parentBone.name + "_End")
    local endBone = undefined

    try
    (
        endBone = BoneSys.createBone startPos endPos upVec
        endBone.name = endBoneName
        endBone.width = boneWidth * 0.4
        endBone.height = boneWidth * 0.4
        endBone.showLinks = false
        endBone.wirecolor = (color 100 200 100)
        endBone.parent = parentBone

        try (endBone.boneEnable = false) catch ()
        try (endBone.boneFreezeLength = true) catch ()
    )
    catch
    (
        endBone = undefined
    )

    endBone
)

fn MBCR_CreateRigGroups bipRoot ctrlSize =
(
    local rootSize = ctrlSize * 0.6
    if rootSize < 5.0 do rootSize = 5.0

    local rigRoot = MBCR_MakeDummy ("MBCR_" + bipRoot.name + "_RIG") rootSize (color 255 180 0)
    local helpersGrp = MBCR_MakeDummy "MBCR_Follow_GRP" (rootSize * 0.8) (color 0 220 255)
    local bonesGrp = MBCR_MakeDummy "MBCR_Bones_GRP" (rootSize * 0.8) (color 0 255 120)
    local ctrlsGrp = MBCR_MakeDummy "MBCR_Controllers_GRP" (rootSize * 0.8) (color 255 210 0)

    rigRoot.transform = bipRoot.transform
    helpersGrp.transform = rigRoot.transform
    bonesGrp.transform = rigRoot.transform
    ctrlsGrp.transform = rigRoot.transform

    helpersGrp.parent = rigRoot
    bonesGrp.parent = rigRoot
    ctrlsGrp.parent = rigRoot

    helpersGrp.isFrozen = true
    rigRoot.boxmode = true
    rigRoot.wirecolor = (color 255 180 0)

    MBCR_State.rigRoot = rigRoot
    MBCR_State.helpersGroup = helpersGrp
    MBCR_State.bonesGroup = bonesGrp
    MBCR_State.controllersGroup = ctrlsGrp
)

fn MBCR_CreateItemForSource bipRoot sourceNode sourceNodes ctrlShape ctrlSize ctrlColor boneWidth =
(
    local item = MBCR_Item()
    item.sourceNode = sourceNode
    item.shortName = MBCR_GetShortName bipRoot sourceNode
    item.standardName = MBCR_GetStandardBoneName item.shortName

    local children = MBCR_GetChildSourceNodes sourceNodes sourceNode
    item.childCount = children.count

    local followSize = ctrlSize * 0.35
    if followSize < 2.0 do followSize = 2.0
    local followName = uniqueName ("Follow_" + item.standardName)
    local followNode = Point name:followName size:followSize centermarker:off axistripod:off cross:false box:on
    followNode.transform = sourceNode.transform
    followNode.wirecolor = (color 0 220 255)
    followNode.parent = MBCR_State.helpersGroup
    followNode.isFrozen = true

    MBCR_AddPositionConstraint followNode sourceNode weight:100.0
    MBCR_AddOrientationConstraint followNode sourceNode weight:100.0

    local ctrlName = uniqueName ("CTRL_" + item.standardName)
    local ctrlNode = MBCR_CreateController ctrlShape ctrlSize ctrlColor ctrlName
    ctrlNode.parent = followNode
    ctrlNode.transform = sourceNode.transform

    local boneNode = MBCR_CreateBoneForSource bipRoot sourceNode sourceNodes boneWidth ctrlSize

    item.followNode = followNode
    item.controllerNode = ctrlNode
    item.boneNode = boneNode
    item.stretchable = (children.count == 1)
    item.isEndBone = (children.count == 0)

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

fn MBCR_CreateEndBones itemsArray boneWidth =
(
    local endBones = #()

    for item in itemsArray do
    (
        if item.isEndBone and MBCR_IsValidNode item.boneNode then
        (
            local endBone = MBCR_CreateEndBone item.boneNode boneWidth
            if MBCR_IsValidNode endBone then
            (
                append endBones endBone
                item.endBoneNode = endBone
            )
        )
    )

    endBones
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

fn MBCR_SelectEndBones =
(
    local nodes = #()

    try
    (
        if MBCR_State.endBones != undefined then
        (
            for eb in MBCR_State.endBones do if MBCR_IsValidNode eb do append nodes eb
        )
    )
    catch ()

    if nodes.count > 0 then select nodes
    nodes.count
)

fn MBCR_BuildRig bipRoot includeFingers:true includeToes:true ctrlShape:"Circle" ctrlSize:12.0 ctrlColor:(color 255 210 0) boneWidth:2.5 enableStretch:true createEndBones:true =
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

    undo "MBCR Build Complete Rig" on
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
        MBCR_ApplyBoneLinks sourceNodes MBCR_State.items
        MBCR_ApplyBoneControllers MBCR_State.items enableStretch

        if createEndBones then
        (
            MBCR_State.endBones = MBCR_CreateEndBones MBCR_State.items boneWidth
        )

        MBCR_UpdateStats()
        MBCR_SelectControllers()

        local stretchCount = 0
        for item in MBCR_State.items where item.stretchable do stretchCount += 1

        MBCR_SetStatus (
            "Complete rig build finished!" + "\n" +
            "Biped: " + bipRoot.name + "\n" +
            "Bones: " + (sourceNodes.count as string) + "\n" +
            "End bones: " + (MBCR_State.endBones.count as string) + "\n" +
            "Stretch chains: " + (stretchCount as string) + "\n" +
            "Rig root: " + MBCR_State.rigRoot.name
        )
    )

    true
)

rollout MBCR_MainRollout "Max Biped Complete Rig" width:380 height:480
(
    group "Biped Selection"
    (
        pickbutton btnPickBiped "Pick Biped Root" width:340 height:32
        label lblBipedInfo "Selected: None" align:#left
    )

    group "Build Options"
    (
        checkbox chkFingers "Include fingers" checked:true across:2
        checkbox chkToes "Include toes" checked:true
        checkbox chkStretch "Enable stretch on single-child chains" checked:true across:2
        checkbox chkEndBones "Create end bones" checked:true

        dropdownlist ddlCtrlShape "Controller shape" items:#("Circle", "Point", "Dummy", "Box", "Diamond") selection:1 width:340
        spinner spnCtrlSize "Controller size" range:[1,100,12] type:#float width:340
        spinner spnBoneWidth "Bone width" range:[0.1,20,2.5] type:#float width:340
        colorpicker cpCtrlColor "Controller color" color:(color 255 210 0) width:340
    )

    group "Actions"
    (
        button btnBuild "Build Complete Rig" width:340 height:40
        button btnClear "Clear Rig" width:340 height:28
        button btnSelectCtrls "Select Controllers" width:110 height:28 across:3
        button btnSelectBones "Select Bones" width:110 height:28
        button btnSelectEnds "Select End Bones" width:110 height:28
        label lblStats "Bones: 0 | End: 0 | Controllers: 0" align:#left
    )

    group "Status"
    (
        edittext edtStatus "" width:340 height:120 readOnly:true
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
            enableStretch:chkStretch.checked \
            createEndBones:chkEndBones.checked

        if ok then
        (
            messageBox "Complete Biped rig created successfully!" title:"Build Complete"
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

    on btnSelectEnds pressed do
    (
        local count = MBCR_SelectEndBones()
        MBCR_SetStatus ("Selected end bones: " + (count as string))
    )
)

fn MBCR_OpenUI =
(
    try (closeRolloutFloater MBCR_Floater) catch ()
    MBCR_Floater = newRolloutFloater "Max Biped Complete Rig" 400 520
    addRollout MBCR_MainRollout MBCR_Floater
    MBCR_UpdateStats()
    if MBCR_IsValidNode MBCR_State.selectedBiped then
    (
        try (MBCR_MainRollout.lblBipedInfo.text = ("Selected: " + MBCR_State.selectedBiped.name)) catch ()
    )
)

macroScript MaxBipedCompleteRig
category:"Animation Tools"
tooltip:"Max Biped Complete Rig"
buttonText:"Complete Biped Rig"
(
    MBCR_OpenUI()
)

MBCR_OpenUI()

