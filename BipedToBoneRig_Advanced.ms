/*
=============================================================================
Biped to Bone Rig Generator - Advanced Version
=============================================================================
功能：
1. 选中Biped自动创建完整的Bone骨骼系统
2. 生成控制器（支持多种形状）
3. 控制器可以移动和拉伸骨骼
4. 控制器被Biped约束
5. 支持手指、脚趾等细节骨骼
6. 提供UI界面进行配置
=============================================================================
*/

try(closeRolloutFloater bipedRigFloater) catch()

global bipedRigFloater
global boneRigData = #()

rollout bipedToBoneRigRollout "Biped to Bone Rig Generator" width:320 height:500
(
	-- UI控件
	group "Biped Selection"
	(
		pickbutton btnPickBiped "Pick Biped Root" width:280 height:30
		label lblBipedName "Selected: None" align:#left
	)

	group "Bone Settings"
	(
		checkbox chkCreateSpine "Create Spine Bones" checked:true
		checkbox chkCreateArms "Create Arm Bones" checked:true
		checkbox chkCreateLegs "Create Leg Bones" checked:true
		checkbox chkCreateFingers "Create Finger Bones" checked:true
		checkbox chkCreateToes "Create Toe Bones" checked:true
		spinner spnBoneWidth "Bone Width:" range:[0.1,10,2] type:#float
	)

	group "Controller Settings"
	(
		dropdownlist ddlCtrlType "Controller Type:" items:#("Point", "Dummy", "Circle", "Box") selection:1
		spinner spnCtrlSize "Controller Size:" range:[1,50,5] type:#float
		colorpicker cpCtrlColor "Controller Color:" color:(color 255 255 0)
	)

	group "Constraint Settings"
	(
		checkbox chkEnableStretch "Enable Stretch (IK)" checked:true
		checkbox chkLinkToParent "Link Controllers to Parent" checked:true
		spinner spnConstraintWeight "Constraint Weight:" range:[0,100,100] type:#float
	)

	button btnGenerate "Generate Rig" width:280 height:40
	button btnClear "Clear Generated Rig" width:280 height:30
	progressBar pbProgress width:280

	-- 全局变量
	local selectedBiped = undefined
	local generatedBones = #()
	local generatedControllers = #()
	local generatedConstraints = #()

	-- 创建不同类型的控制器
	fn createControllerShape ctrlType ctrlSize ctrlColor = (
		local ctrl = undefined
		case ctrlType of
		(
			"Point": ctrl = Point size:ctrlSize centermarker:on axistripod:on cross:off box:on
			"Dummy": ctrl = Dummy()
			"Circle": (
				ctrl = Circle radius:ctrlSize
			)
			"Box": (
				ctrl = Box length:ctrlSize width:ctrlSize height:ctrlSize
				ctrl.wirecolor = ctrlColor
			)
			default: ctrl = Point size:ctrlSize
		)
		if ctrl != undefined then
			ctrl.wirecolor = ctrlColor
		return ctrl
	)

	-- 获取Biped所有骨骼（包括手指脚趾）
	fn getAllBipedBones bip includeFingers:true includeToes:true = (
		local bones = #()
		local names = #()

		try (
			-- 根节点
			append bones bip.controller.rootNode
			append names "Root"

			-- 脊柱
			for i = 1 to bip.controller.spine.count do (
				append bones bip.controller.spine[i].node
				append names ("Spine" + i as string)
			)

			-- 颈部
			for i = 1 to bip.controller.neck.count do (
				append bones bip.controller.neck[i].node
				append names ("Neck" + i as string)
			)

			-- 头部
			append bones bip.controller.head.node
			append names "Head"

			-- 左臂
			append bones bip.controller.leftArm.node
			append names "L_UpperArm"
			append bones bip.controller.leftForeArm.node
			append names "L_ForeArm"
			append bones bip.controller.leftHand.node
			append names "L_Hand"

			-- 左手指
			if includeFingers and bip.controller.leftHand.fingers != undefined then (
				for f = 1 to bip.controller.leftHand.fingers.count do (
					for p = 1 to bip.controller.leftHand.fingers[f].count do (
						append bones bip.controller.leftHand.fingers[f][p].node
						append names ("L_Finger" + f as string + "_" + p as string)
					)
				)
			)

			-- 右臂
			append bones bip.controller.rightArm.node
			append names "R_UpperArm"
			append bones bip.controller.rightForeArm.node
			append names "R_ForeArm"
			append bones bip.controller.rightHand.node
			append names "R_Hand"

			-- 右手指
			if includeFingers and bip.controller.rightHand.fingers != undefined then (
				for f = 1 to bip.controller.rightHand.fingers.count do (
					for p = 1 to bip.controller.rightHand.fingers[f].count do (
						append bones bip.controller.rightHand.fingers[f][p].node
						append names ("R_Finger" + f as string + "_" + p as string)
					)
				)
			)

			-- 左腿
			append bones bip.controller.leftThigh.node
			append names "L_Thigh"
			append bones bip.controller.leftCalf.node
			append names "L_Calf"
			append bones bip.controller.leftFoot.node
			append names "L_Foot"

			-- 左脚趾
			if includeToes and bip.controller.leftFoot.toes != undefined then (
				for t = 1 to bip.controller.leftFoot.toes.count do (
					append bones bip.controller.leftFoot.toes[t].node
					append names ("L_Toe" + t as string)
				)
			)

			-- 右腿
			append bones bip.controller.rightThigh.node
			append names "R_Thigh"
			append bones bip.controller.rightCalf.node
			append names "R_Calf"
			append bones bip.controller.rightFoot.node
			append names "R_Foot"

			-- 右脚趾
			if includeToes and bip.controller.rightFoot.toes != undefined then (
				for t = 1 to bip.controller.rightFoot.toes.count do (
					append bones bip.controller.rightFoot.toes[t].node
					append names ("R_Toe" + t as string)
				)
			)

		) catch (
			format "Error getting biped bones: %\n" (getCurrentException())
		)

		return #(bones, names)
	)

	-- 创建Bone骨骼
	fn createBoneFromBiped bipBone boneName boneWidth = (
		local bipPos = bipBone.transform.pos
		local newBone = BoneSys.createBone bipPos bipPos [0,0,1]
		newBone.name = "Bone_" + boneName
		newBone.width = boneWidth
		newBone.height = boneWidth
		newBone.transform = bipBone.transform
		newBone.showLinks = true
		newBone.wirecolor = color 0 255 0
		return newBone
	)

	-- 设置骨骼层级
	fn setupHierarchy objects sourceObjects = (
		for i = 1 to objects.count do (
			if sourceObjects[i].parent != undefined then (
				local parentIndex = findItem sourceObjects sourceObjects[i].parent
				if parentIndex > 0 and parentIndex <= objects.count then
					objects[i].parent = objects[parentIndex]
			)
		)
	)

	-- 添加位置和旋转约束
	fn addTransformConstraint target source weight = (
		-- 位置约束
		local posConst = Position_Constraint()
		target.pos.controller = posConst
		posConst.appendTarget source weight

		-- 旋转约束
		local rotConst = Orientation_Constraint()
		target.rotation.controller = rotConst
		rotConst.appendTarget source weight
	)

	-- Pick Biped按钮事件
	on btnPickBiped picked obj do (
		if obj != undefined then (
			if classOf obj.controller == Vertical_Horizontal_Turn then (
				selectedBiped = obj
				lblBipedName.text = "Selected: " + obj.name
				btnPickBiped.text = obj.name
			) else (
				messageBox "Please select a Biped root node!"
				selectedBiped = undefined
			)
		)
	)

	-- 生成绑定按钮事件
	on btnGenerate pressed do (
		if selectedBiped == undefined then (
			messageBox "Please pick a Biped first!"
			return false
		)

		undo "Generate Biped Bone Rig" on (
			generatedBones = #()
			generatedControllers = #()
			generatedConstraints = #()

			pbProgress.value = 0

			-- 获取Biped骨骼
			local result = getAllBipedBones selectedBiped \
				includeFingers:chkCreateFingers.checked \
				includeToes:chkCreateToes.checked
			local bipBones = result[1]
			local boneNames = result[2]

			if bipBones.count == 0 then (
				messageBox "Failed to get Biped bones!"
				return false
			)

			local totalSteps = bipBones.count * 3
			local currentStep = 0

			-- 创建Bone骨骼
			for i = 1 to bipBones.count do (
				local newBone = createBoneFromBiped bipBones[i] boneNames[i] spnBoneWidth.value
				append generatedBones newBone
				currentStep += 1
				pbProgress.value = (currentStep * 100.0 / totalSteps)
			)

			-- 设置骨骼层级
			setupHierarchy generatedBones bipBones
			currentStep += bipBones.count
			pbProgress.value = (currentStep * 100.0 / totalSteps)

			-- 创建控制器
			for i = 1 to generatedBones.count do (
				local ctrl = createControllerShape ddlCtrlType.selected spnCtrlSize.value cpCtrlColor.color
				if ctrl != undefined then (
					ctrl.name = generatedBones[i].name + "_CTRL"
					ctrl.transform = generatedBones[i].transform
					append generatedControllers ctrl

					-- 设置控制器层级
					if chkLinkToParent.checked and generatedBones[i].parent != undefined then (
						local parentIndex = findItem generatedBones generatedBones[i].parent
						if parentIndex > 0 then
							ctrl.parent = generatedControllers[parentIndex]
					)
				)
				currentStep += 1
				pbProgress.value = (currentStep * 100.0 / totalSteps)
			)

			-- 添加约束：控制器驱动Bone
			for i = 1 to generatedBones.count do (
				addTransformConstraint generatedBones[i] generatedControllers[i] spnConstraintWeight.value
			)

			-- 添加约束：Biped约束控制器
			for i = 1 to generatedControllers.count do (
				addTransformConstraint generatedControllers[i] bipBones[i] spnConstraintWeight.value
			)

			pbProgress.value = 100
			messageBox (format "Successfully created % bones and % controllers!" generatedBones.count generatedControllers.count)
		)
	)

	-- 清除生成的绑定
	on btnClear pressed do (
		if generatedBones.count > 0 or generatedControllers.count > 0 then (
			if queryBox "Are you sure you want to delete all generated bones and controllers?" then (
				undo "Clear Biped Bone Rig" on (
					for obj in generatedControllers do delete obj
					for obj in generatedBones do delete obj
					generatedBones = #()
					generatedControllers = #()
					generatedConstraints = #()
					pbProgress.value = 0
					messageBox "Rig cleared successfully!"
				)
			)
		) else (
			messageBox "No rig to clear!"
		)
	)
)

-- 创建浮动窗口
bipedRigFloater = newRolloutFloater "Biped to Bone Rig" 340 540
addRollout bipedToBoneRigRollout bipedRigFloater
