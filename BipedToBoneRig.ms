/*
=============================================================================
Biped to Bone Rig Generator
=============================================================================
功能：选中Biped自动创建完整的Bone骨骼系统，生成控制器，实现控制器驱动骨骼并被Biped约束
作者：Auto Generated
版本：1.0
=============================================================================
*/

macroScript BipedToBoneRig
category:"Animation Tools"
tooltip:"Biped to Bone Rig"
buttonText:"Biped->Bone Rig"
(
	-- 全局变量
	local bipedRoot = undefined
	local boneArray = #()
	local controllerArray = #()
	local bipedBoneMapping = #()

	-- Biped骨骼名称映射表
	fn getBipedBoneList bip = (
		local bones = #()
		-- 脊柱
		append bones (bip.controller.rootNode)
		for i = 1 to bip.controller.spine.count do
			append bones bip.controller.spine[i].node
		-- 颈部和头部
		for i = 1 to bip.controller.neck.count do
			append bones bip.controller.neck[i].node
		append bones bip.controller.head.node

		-- 左臂
		append bones bip.controller.leftArm.node
		append bones bip.controller.leftForeArm.node
		append bones bip.controller.leftHand.node

		-- 右臂
		append bones bip.controller.rightArm.node
		append bones bip.controller.rightForeArm.node
		append bones bip.controller.rightHand.node

		-- 左腿
		append bones bip.controller.leftThigh.node
		append bones bip.controller.leftCalf.node
		append bones bip.controller.leftFoot.node

		-- 右腿
		append bones bip.controller.rightThigh.node
		append bones bip.controller.rightCalf.node
		append bones bip.controller.rightFoot.node

		return bones
	)

	-- 创建Bone骨骼
	fn createBoneFromBiped bipBone boneName = (
		local bipPos = bipBone.transform.pos
		local newBone = BoneSys.createBone bipPos bipPos [0,0,1]
		newBone.name = boneName
		newBone.width = 2
		newBone.height = 2
		newBone.transform = bipBone.transform
		newBone.showLinks = true
		newBone.wirecolor = color 0 255 0
		return newBone
	)

	-- 创建控制器（使用Point或Dummy）
	fn createController boneName ctrlPos = (
		local ctrl = Point size:5 centermarker:on axistripod:on cross:off box:on
		ctrl.name = boneName + "_CTRL"
		ctrl.transform.pos = ctrlPos
		ctrl.wirecolor = color 255 255 0
		return ctrl
	)

	-- 设置骨骼层级关系
	fn setupBoneHierarchy bones bipBones = (
		for i = 1 to bones.count do (
			if bipBones[i].parent != undefined then (
				local parentIndex = findItem bipBones bipBones[i].parent
				if parentIndex > 0 then
					bones[i].parent = bones[parentIndex]
			)
		)
	)

	-- 添加位置约束
	fn addPositionConstraint target controller = (
		local posConst = Position_Constraint()
		target.pos.controller = posConst
		posConst.appendTarget controller 100.0
	)

	-- 添加旋转约束
	fn addRotationConstraint target controller = (
		local rotConst = Orientation_Constraint()
		target.rotation.controller = rotConst
		rotConst.appendTarget controller 100.0
	)

	-- 添加LookAt约束（用于骨骼拉伸）
	fn addStretchConstraint bone startCtrl endCtrl = (
		-- 使用IK Solver实现拉伸效果
		local ikChain = IKSys.ikChain bone endCtrl "IKHISolver"
		return ikChain
	)

	-- 主函数
	fn createBipedBoneRig = (
		if selection.count == 0 then (
			messageBox "请先选择一个Biped对象！"
			return false
		)

		local sel = selection[1]

		-- 检查是否是Biped
		if classOf sel.controller != Vertical_Horizontal_Turn then (
			messageBox "选中的对象不是Biped根节点！"
			return false
		)

		bipedRoot = sel
		boneArray = #()
		controllerArray = #()

		-- 获取所有Biped骨骼
		local bipBones = getBipedBoneList bipedRoot

		if bipBones.count == 0 then (
			messageBox "无法获取Biped骨骼列表！"
			return false
		)

		undo "Create Biped Bone Rig" on (
			-- 创建Bone骨骼
			for i = 1 to bipBones.count do (
				local boneName = "Bone_" + bipBones[i].name
				local newBone = createBoneFromBiped bipBones[i] boneName
				append boneArray newBone
			)

			-- 设置骨骼层级
			setupBoneHierarchy boneArray bipBones

			-- 创建控制器
			for i = 1 to boneArray.count do (
				local ctrl = createController boneArray[i].name boneArray[i].transform.pos
				ctrl.transform = boneArray[i].transform
				append controllerArray ctrl

				-- 设置控制器层级（与骨骼层级一致）
				if boneArray[i].parent != undefined then (
					local parentIndex = findItem boneArray boneArray[i].parent
					if parentIndex > 0 then
						ctrl.parent = controllerArray[parentIndex]
				)
			)

			-- 添加约束：控制器控制Bone
			for i = 1 to boneArray.count do (
				addPositionConstraint boneArray[i] controllerArray[i]
				addRotationConstraint boneArray[i] controllerArray[i]
			)

			-- 添加约束：Biped约束控制器
			for i = 1 to controllerArray.count do (
				addPositionConstraint controllerArray[i] bipBones[i]
				addRotationConstraint controllerArray[i] bipBones[i]
			)

			-- 创建拉伸控制（针对四肢）
			-- 这里可以添加更复杂的拉伸逻辑

			format "成功创建 % 个骨骼和 % 个控制器\n" boneArray.count controllerArray.count
		)

		return true
	)

	-- 执行主函数
	on execute do (
		createBipedBoneRig()
	)
)
