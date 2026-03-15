-- Biped Custom Rig - 简化测试版
-- 如果主版本无法运行，请使用这个版本测试

(
	-- 全局变量
	global bipedObj = undefined
	global customBones = #()
	global locators = #()

	-- 辅助函数
	fn getBipedBone bipRoot boneName =
	(
		try
		(
			local fullName = bipRoot.name + " " + boneName
			return getNodeByName fullName
		)
		catch
		(
			return undefined
		)
	)

	-- UI界面
	rollout bipedRigRollout "Biped绑定工具 - 简化版" width:320 height:500
	(
		group "Biped选择"
		(
			pickbutton btnPickBiped "选择Biped根节点" width:280 height:30
			label lblBipedInfo "未选择" align:#left
		)

		group "设置"
		(
			spinner spnCtrlSize "控制器大小:" range:[1,50,5] type:#float width:280
			spinner spnLocSize "Locator大小:" range:[1,20,3] type:#float width:280
			checkbox chkUseLocator "使用Locator" checked:true
		)

		group "快速选择"
		(
			button btnSelSpine "脊柱" width:65 height:25 across:4
			button btnSelNeck "颈部" width:65 height:25
			button btnSelLArm "左臂" width:65 height:25
			button btnSelRArm "右臂" width:65 height:25
		)

		group "操作"
		(
			button btnRigSelected "绑定选中骨骼" width:280 height:35
			button btnAutoRigAll "自动绑定全身" width:280 height:35
		)

		group "管理"
		(
			button btnSelectCtrls "选择控制器" width:135 height:25 across:2
			button btnSelectLocs "选择Locator" width:135 height:25
			button btnClearAll "清除绑定" width:280 height:30
		)

		label lblInfo "就绪" style_sunkenedge:true height:30

		-- 选择Biped
		on btnPickBiped picked obj do
		(
			try
			(
				if classof obj.controller == Vertical_Horizontal_Turn then
				(
					bipedObj = obj
					lblBipedInfo.text = obj.name
					lblInfo.text = "Biped已设置"
				)
				else
				(
					lblInfo.text = "不是Biped根节点"
				)
			)
			catch
			(
				lblInfo.text = "选择失败"
			)
		)

		-- 选择脊柱
		on btnSelSpine pressed do
		(
			if bipedObj == undefined then
			(
				lblInfo.text = "请先选择Biped"
				return false
			)

			local bones = #()
			for i = 1 to 4 do
			(
				local bone = getBipedBone bipedObj ("Spine" + (if i > 1 then i as string else ""))
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
			lblInfo.text = "已选择脊柱"
		)

		-- 选择颈部
		on btnSelNeck pressed do
		(
			if bipedObj == undefined then return false
			local bone = getBipedBone bipedObj "Neck"
			if bone != undefined then select bone
		)

		-- 选择左臂
		on btnSelLArm pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L UpperArm", "L Forearm", "L Hand") do
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
			for part in #("R UpperArm", "R Forearm", "R Hand") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 绑定选中骨骼
		on btnRigSelected pressed do
		(
			if bipedObj == undefined then
			(
				messageBox "请先选择Biped根节点！"
				return false
			)

			if selection.count == 0 then
			(
				messageBox "请先选择要绑定的骨骼！"
				return false
			)

			try
			(
				local count = 0
				for bipBone in selection do
				(
					-- 创建控制器
					local ctrlName = "Ctrl_" + bipBone.name
					ctrlName = substituteString ctrlName (bipedObj.name + " ") ""
					ctrlName = substituteString ctrlName " " "_"

					local ctrl = Box length:spnCtrlSize.value width:spnCtrlSize.value height:spnCtrlSize.value
					ctrl.name = ctrlName
					ctrl.pos = bipBone.pos
					ctrl.rotation = bipBone.rotation
					ctrl.wirecolor = color 255 200 0

					-- 创建Locator
					if chkUseLocator.checked then
					(
						local loc = Point size:spnLocSize.value name:("Loc_" + ctrlName) cross:false box:true
						loc.pos = bipBone.pos
						loc.rotation = bipBone.rotation
						loc.wirecolor = color 0 255 255

						-- 约束Locator到Biped
						local posConst = Position_Constraint()
						loc.pos.controller = posConst
						posConst.appendTarget bipBone 100

						local oriConst = Orientation_Constraint()
						loc.rotation.controller = oriConst
						oriConst.appendTarget bipBone 100

						-- 控制器作为Locator的子级
						ctrl.parent = loc

						append locators loc
					)

					append customBones ctrl
					count += 1
				)

				lblInfo.text = "创建了 " + (count as string) + " 个控制器"
			)
			catch
			(
				lblInfo.text = "绑定失败: " + (getCurrentException())
			)
		)

		-- 自动绑定全身
		on btnAutoRigAll pressed do
		(
			if bipedObj == undefined then
			(
				messageBox "请先选择Biped根节点！"
				return false
			)

			try
			(
				local boneNames = #(
					"Pelvis", "Spine", "Spine1", "Neck", "Head",
					"L UpperArm", "L Forearm", "L Hand",
					"R UpperArm", "R Forearm", "R Hand",
					"L Thigh", "L Calf", "L Foot",
					"R Thigh", "R Calf", "R Foot"
				)

				local count = 0
				for boneName in boneNames do
				(
					local bipBone = getBipedBone bipedObj boneName
					if bipBone != undefined then
					(
						local ctrlName = "Ctrl_" + (substituteString boneName " " "_")
						local ctrl = Box length:spnCtrlSize.value width:spnCtrlSize.value height:spnCtrlSize.value
						ctrl.name = ctrlName
						ctrl.pos = bipBone.pos
						ctrl.rotation = bipBone.rotation
						ctrl.wirecolor = color 255 200 0

						if chkUseLocator.checked then
						(
							local loc = Point size:spnLocSize.value name:("Loc_" + ctrlName) cross:false box:true
							loc.pos = bipBone.pos
							loc.rotation = bipBone.rotation
							loc.wirecolor = color 0 255 255

							local posConst = Position_Constraint()
							loc.pos.controller = posConst
							posConst.appendTarget bipBone 100

							local oriConst = Orientation_Constraint()
							loc.rotation.controller = oriConst
							oriConst.appendTarget bipBone 100

							ctrl.parent = loc
							append locators loc
						)

						append customBones ctrl
						count += 1
					)
				)

				lblInfo.text = "全身绑定完成: " + (count as string) + " 个"
			)
			catch
			(
				lblInfo.text = "自动绑定失败"
			)
		)

		-- 选择控制器
		on btnSelectCtrls pressed do
		(
			local valid = #()
			for obj in customBones do
				if isValidNode obj then append valid obj
			if valid.count > 0 then select valid
			lblInfo.text = "已选择 " + (valid.count as string) + " 个控制器"
		)

		-- 选择Locator
		on btnSelectLocs pressed do
		(
			local valid = #()
			for obj in locators do
				if isValidNode obj then append valid obj
			if valid.count > 0 then select valid
			lblInfo.text = "已选择 " + (valid.count as string) + " 个Locator"
		)

		-- 清除
		on btnClearAll pressed do
		(
			if queryBox "确定删除所有绑定？" then
			(
				for obj in customBones do if isValidNode obj then delete obj
				for obj in locators do if isValidNode obj then delete obj
				customBones = #()
				locators = #()
				lblInfo.text = "已清除"
			)
		)
	)

	-- 创建对话框
	createDialog bipedRigRollout
)

print "Biped Custom Rig 简化版已加载"
print "如果看到对话框，说明脚本运行成功！"
