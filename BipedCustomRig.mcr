-- Biped Custom Rig Tool for 3ds Max 2023+
-- 自定义Biped骨骼绑定工具

macroScript BipedCustomRig
	category:"Animation Tools"
	tooltip:"Biped Custom Rig"
	buttonText:"Biped Rig"
	icon:#("Biped",1)
(
	-- 全局变量
	global bipedObj = undefined
	global customBones = #()
	global locators = #()
	global bipedRigDialog

	-- 辅助函数：获取Biped骨骼
	fn getBipedBone bipRoot boneName =
	(
		local fullName = bipRoot.name + " " + boneName
		return getNodeByName fullName
	)

	-- 辅助函数：创建约束系统
	fn createConstraintSystem targetObj bipBone createLocator locatorSize =
	(
		local locator = undefined

		if createLocator then
		(
			locator = Point size:locatorSize name:("Loc_" + targetObj.name) cross:false box:true
			locator.pos = bipBone.pos
			locator.rotation = bipBone.rotation
			locator.wirecolor = color 0 255 255

			-- 约束Locator到Biped骨骼
			local posConst = Position_Constraint()
			locator.pos.controller = posConst
			posConst.appendTarget bipBone 100

			local oriConst = Orientation_Constraint()
			locator.rotation.controller = oriConst
			oriConst.appendTarget bipBone 100

			-- 设置控制器为Locator的子级
			targetObj.parent = locator
		)

		return locator
	)

	-- UI界面
	rollout bipedRigRollout "Biped自定义绑定工具" width:340 height:650
	(
		-- Biped选择组
		group "1. Biped骨骼选择"
		(
			pickbutton btnPickBiped "选择Biped根节点" width:300 height:35
			label lblBipedInfo "未选择Biped" align:#left
		)

		-- 控制器设置
		group "2. 控制器设置"
		(
			spinner spnCtrlSize "控制器大小:" range:[0.1,100,5] type:#float width:300
			colorpicker cpCtrlColor "控制器颜色:" color:(color 255 200 0) width:300 height:25
		)

		-- Locator设置
		group "3. Locator设置"
		(
			checkbox chkUseLocator "使用父级Locator" checked:true
			spinner spnLocSize "Locator大小:" range:[0.1,100,3] type:#float width:300
		)

		-- 快速选择
		group "4. 快速选择骨骼"
		(
			button btnSelSpine "脊柱" width:70 height:25 across:4
			button btnSelNeck "颈部" width:70 height:25
			button btnSelHead "头部" width:70 height:25
			button btnSelPelvis "骨盆" width:70 height:25

			button btnSelLArm "左臂" width:70 height:25 across:4
			button btnSelRArm "右臂" width:70 height:25
			button btnSelLLeg "左腿" width:70 height:25
			button btnSelRLeg "右腿" width:70 height:25
		)

		-- 绑定操作
		group "5. 绑定操作"
		(
			button btnRigSelected "绑定选中的Biped骨骼" width:300 height:40
			button btnAutoRigAll "自动绑定全身" width:300 height:40
		)

		-- 工具
		group "6. 工具"
		(
			button btnSelectCtrls "选择所有控制器" width:145 height:30 across:2
			button btnSelectLocs "选择所有Locator" width:145 height:30
			button btnBakeAnim "烘焙动画到控制器" width:300 height:30
			button btnClearAll "清除所有绑定" width:300 height:30
		)

		-- 信息显示
		edittext edtInfo "" height:60 readOnly:true

		-- 选择Biped
		on btnPickBiped picked obj do
		(
			if classof obj.controller == Vertical_Horizontal_Turn then
			(
				bipedObj = obj
				lblBipedInfo.text = "已选择: " + obj.name
				edtInfo.text = "Biped根节点已设置，可以开始绑定"
			)
			else
			(
				messageBox "请选择Biped根节点！" title:"错误"
				edtInfo.text = "错误: 不是有效的Biped对象"
			)
		)

		-- 选择脊柱
		on btnSelSpine pressed do
		(
			if bipedObj == undefined then
			(
				messageBox "请先选择Biped根节点！" title:"提示"
				return false
			)

			local spines = #()
			for i = 1 to 4 do
			(
				local spine = getBipedBone bipedObj ("Spine" + (if i > 1 then i as string else ""))
				if spine != undefined then append spines spine
			)
			if spines.count > 0 then
			(
				select spines
				edtInfo.text = "已选择 " + (spines.count as string) + " 个脊柱骨骼"
			)
		)

		-- 选择颈部
		on btnSelNeck pressed do
		(
			if bipedObj == undefined then return false
			local necks = #()
			for i = 1 to 3 do
			(
				local neck = getBipedBone bipedObj ("Neck" + (if i > 1 then i as string else ""))
				if neck != undefined then append necks neck
			)
			if necks.count > 0 then select necks
		)

		-- 选择头部
		on btnSelHead pressed do
		(
			if bipedObj == undefined then return false
			local head = getBipedBone bipedObj "Head"
			if head != undefined then select head
		)

		-- 选择骨盆
		on btnSelPelvis pressed do
		(
			if bipedObj == undefined then return false
			local pelvis = getBipedBone bipedObj "Pelvis"
			if pelvis != undefined then select pelvis
		)

		-- 选择左臂
		on btnSelLArm pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L Clavicle", "L UpperArm", "L Forearm", "L Hand") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择右臂
		on btnSelRArm pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("R Clavicle", "R UpperArm", "R Forearm", "R Hand") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择左腿
		on btnSelLLeg pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L Thigh", "L Calf", "L Foot") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择右腿
		on btnSelRLeg pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("R Thigh", "R Calf", "R Foot") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 绑定选中的骨骼
		on btnRigSelected pressed do
		(
			if bipedObj == undefined then
			(
				messageBox "请先选择Biped根节点！" title:"错误"
				return false
			)

			if selection.count == 0 then
			(
				messageBox "请先选择要绑定的Biped骨骼！" title:"错误"
				return false
			)

			try
			(
				local newCtrls = #()
				local newLocs = #()

				for bipBone in selection do
				(
					-- 创建控制器
					local ctrlName = "Ctrl_" + (substituteString bipBone.name (bipedObj.name + " ") "")
					ctrlName = substituteString ctrlName " " "_"

					local ctrl = Box length:spnCtrlSize.value width:spnCtrlSize.value height:spnCtrlSize.value name:ctrlName
					ctrl.pos = bipBone.pos
					ctrl.rotation = bipBone.rotation
					ctrl.wirecolor = cpCtrlColor.color

					-- 创建约束系统
					local locator = createConstraintSystem ctrl bipBone chkUseLocator.checked spnLocSize.value

					append newCtrls ctrl
					append customBones ctrl
					if locator != undefined then
					(
						append newLocs locator
						append locators locator
					)
				)

				select newCtrls
				edtInfo.text = "绑定完成！创建了 " + (newCtrls.count as string) + " 个控制器"
			)
			catch
			(
				edtInfo.text = "绑定失败: " + (getCurrentException())
			)
		)

		-- 自动绑定全身
		on btnAutoRigAll pressed do
		(
			if bipedObj == undefined then
			(
				messageBox "请先选择Biped根节点！" title:"错误"
				return false
			)

			try
			(
				local boneList = #(
					"Pelvis", "Spine", "Spine1", "Spine2", "Spine3",
					"Neck", "Head",
					"L Clavicle", "L UpperArm", "L Forearm", "L Hand",
					"R Clavicle", "R UpperArm", "R Forearm", "R Hand",
					"L Thigh", "L Calf", "L Foot",
					"R Thigh", "R Calf", "R Foot"
				)

				local newCtrls = #()

				for boneName in boneList do
				(
					local bipBone = getBipedBone bipedObj boneName
					if bipBone != undefined then
					(
						local ctrlName = "Ctrl_" + (substituteString boneName " " "_")
						local ctrl = Box length:spnCtrlSize.value width:spnCtrlSize.value height:spnCtrlSize.value name:ctrlName
						ctrl.pos = bipBone.pos
						ctrl.rotation = bipBone.rotation
						ctrl.wirecolor = cpCtrlColor.color

						local locator = createConstraintSystem ctrl bipBone chkUseLocator.checked spnLocSize.value

						append newCtrls ctrl
						append customBones ctrl
						if locator != undefined then append locators locator
					)
				)

				select newCtrls
				edtInfo.text = "全身绑定完成！创建了 " + (newCtrls.count as string) + " 个控制器"
			)
			catch
			(
				edtInfo.text = "自动绑定失败: " + (getCurrentException())
			)
		)

		-- 选择所有控制器
		on btnSelectCtrls pressed do
		(
			local validCtrls = #()
			for obj in customBones do
				if isValidNode obj then append validCtrls obj

			if validCtrls.count > 0 then
			(
				select validCtrls
				edtInfo.text = "已选择 " + (validCtrls.count as string) + " 个控制器"
			)
			else
				edtInfo.text = "没有找到控制器"
		)

		-- 选择所有Locator
		on btnSelectLocs pressed do
		(
			local validLocs = #()
			for obj in locators do
				if isValidNode obj then append validLocs obj

			if validLocs.count > 0 then
			(
				select validLocs
				edtInfo.text = "已选择 " + (validLocs.count as string) + " 个Locator"
			)
			else
				edtInfo.text = "没有找到Locator"
		)

		-- 烘焙动画
		on btnBakeAnim pressed do
		(
			if customBones.count == 0 then
			(
				messageBox "没有找到控制器！" title:"错误"
				return false
			)

			try
			(
				local startFrame = animationRange.start
				local endFrame = animationRange.end
				local validCtrls = #()

				for obj in customBones do
					if isValidNode obj then append validCtrls obj

				if validCtrls.count > 0 then
				(
					for ctrl in validCtrls do
					(
						-- 烘焙变换
						with animate on
						(
							for t = startFrame to endFrame do
							(
								at time t
								(
									ctrl.pos = ctrl.pos
									ctrl.rotation = ctrl.rotation
								)
							)
						)
					)
					edtInfo.text = "动画已烘焙到 " + (validCtrls.count as string) + " 个控制器"
				)
			)
			catch
			(
				edtInfo.text = "烘焙失败: " + (getCurrentException())
			)
		)

		-- 清除所有
		on btnClearAll pressed do
		(
			if queryBox "确定要删除所有控制器和Locator吗？" title:"确认" then
			(
				try
				(
					local deleteCount = 0
					for obj in customBones do
					(
						if isValidNode obj then
						(
							delete obj
							deleteCount += 1
						)
					)
					for obj in locators do
					(
						if isValidNode obj then
						(
							delete obj
							deleteCount += 1
						)
					)
					customBones = #()
					locators = #()
					edtInfo.text = "已删除 " + (deleteCount as string) + " 个对象"
				)
				catch
				(
					edtInfo.text = "清除失败: " + (getCurrentException())
				)
			)
		)
	)

	-- 创建或显示对话框
	on execute do
	(
		if bipedRigDialog != undefined and bipedRigDialog.isDisplayed then
			destroyDialog bipedRigDialog

		bipedRigDialog = bipedRigRollout
		createDialog bipedRigDialog
	)
)
