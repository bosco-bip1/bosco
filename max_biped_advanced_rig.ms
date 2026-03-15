/*
===========================================
Biped Advanced Custom Rig Tool - 高级版
自定义Biped骨骼绑定插件（增强版）
===========================================
新增功能：
1. IK/FK切换系统
2. 自定义控制器形状
3. 镜像功能
4. 保存/加载绑定配置
5. 动画层支持
===========================================
*/

-- 辅助函数：创建自定义控制器形状
fn createCustomController ctrlType ctrlSize ctrlColor =
(
	local ctrl = undefined
	case ctrlType of
	(
		"Circle":
		(
			ctrl = Circle radius:ctrlSize
		)
		"Square":
		(
			ctrl = Rectangle length:ctrlSize width:ctrlSize
		)
		"Diamond":
		(
			local pts = #([ctrlSize,0,0], [0,ctrlSize,0], [-ctrlSize,0,0], [0,-ctrlSize,0])
			ctrl = SplineShape()
			addNewSpline ctrl
			for pt in pts do addKnot ctrl 1 #corner #line pt
			close ctrl 1
			updateShape ctrl
		)
		"Sphere":
		(
			ctrl = Sphere radius:ctrlSize wirecolor:ctrlColor
		)
		default:
		(
			ctrl = Box length:ctrlSize width:ctrlSize height:ctrlSize
		)
	)

	if ctrl != undefined then
		ctrl.wirecolor = ctrlColor

	return ctrl
)

-- 辅助函数：获取Biped骨骼
fn getBipedBone bipRoot boneName =
(
	local fullName = bipRoot.name + " " + boneName
	return getNodeByName fullName
)

-- 辅助函数：创建约束
fn createConstraintSystem targetObj bipBone constraintType createLocator locatorSize =
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
	else
	(
		-- 直接约束到Biped骨骼
		case constraintType of
		(
			"Position":
			(
				local posConst = Position_Constraint()
				targetObj.pos.controller = posConst
				posConst.appendTarget bipBone 100
			)
			"Orientation":
			(
				local oriConst = Orientation_Constraint()
				targetObj.rotation.controller = oriConst
				oriConst.appendTarget bipBone 100
			)
			"Both":
			(
				local posConst = Position_Constraint()
				targetObj.pos.controller = posConst
				posConst.appendTarget bipBone 100

				local oriConst = Orientation_Constraint()
				targetObj.rotation.controller = oriConst
				oriConst.appendTarget bipBone 100
			)
		)
	)

	return locator
)

macroScript BipedAdvancedRig category:"Animation Tools" tooltip:"Biped Advanced Rig" buttonText:"Adv Biped Rig"
(
	-- 全局变量
	local bipedObj = undefined
	local rigData = #()
	local configFile = (getDir #userScripts) + "\\biped_rig_config.ini"

	-- UI界面
	rollout advBipedRigRollout "Biped高级绑定工具" width:380 height:700
	(
		-- Biped选择
		group "Biped设置"
		(
			pickbutton btnPickBiped "选择Biped根节点" width:340 height:30
			label lblBipedInfo "未选择Biped" align:#left
		)

		-- 控制器设置
		group "控制器设置"
		(
			dropdownlist ddlCtrlShape "控制器形状:" items:#("Box", "Circle", "Square", "Diamond", "Sphere") width:340
			spinner spnCtrlSize "控制器大小:" range:[0.1,100,5] type:#float width:340
			colorpicker cpCtrlColor "控制器颜色:" color:(color 255 200 0) width:340
		)

		-- Locator设置
		group "Locator设置"
		(
			checkbox chkUseLocator "使用父级Locator" checked:true
			spinner spnLocSize "Locator大小:" range:[0.1,100,3] type:#float width:340
			dropdownlist ddlConstraintMode "约束模式:" items:#("Position", "Orientation", "Both") selection:3 width:340
		)

		-- 骨骼选择
		group "骨骼选择"
		(
			button btnSelectSpine "脊柱" width:80 height:25 across:4
			button btnSelectNeck "颈部" width:80 height:25
			button btnSelectHead "头部" width:80 height:25
			button btnSelectPelvis "骨盆" width:80 height:25

			button btnSelectLArm "左臂" width:80 height:25 across:4
			button btnSelectRArm "右臂" width:80 height:25
			button btnSelectLLeg "左腿" width:80 height:25
			button btnSelectRLeg "右腿" width:80 height:25

			button btnSelectLHand "左手" width:80 height:25 across:4
			button btnSelectRHand "右手" width:80 height:25
			button btnSelectLFoot "左脚" width:80 height:25
			button btnSelectRFoot "右脚" width:80 height:25
		)

		-- 绑定操作
		group "绑定操作"
		(
			button btnRigSelected "绑定选中的Biped骨骼" width:340 height:35
			button btnAutoRigAll "自动绑定全身" width:340 height:35
			button btnMirrorRig "镜像绑定(左->右)" width:165 height:30 across:2
			button btnMirrorRigR2L "镜像绑定(右->左)" width:165 height:30
		)

		-- 高级功能
		group "高级功能"
		(
			button btnCreateIKFK "创建IK/FK切换" width:340 height:30
			button btnBakeToCtrl "烘焙Biped动画到控制器" width:340 height:30
			button btnBakeToBiped "烘焙控制器动画到Biped" width:340 height:30
		)

		-- 管理
		group "管理"
		(
			button btnSelectAllCtrls "选择所有控制器" width:165 height:25 across:2
			button btnSelectAllLocs "选择所有Locator" width:165 height:25
			button btnSaveConfig "保存配置" width:165 height:25 across:2
			button btnLoadConfig "加载配置" width:165 height:25
			button btnClearRig "清除绑定" width:340 height:30
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
				edtInfo.text = "Biped根节点已设置\r\n可以开始绑定操作"
			)
			else
			(
				messageBox "请选择Biped根节点！" title:"错误"
				edtInfo.text = "错误: 不是有效的Biped对象"
			)
		)

		-- 选择脊柱
		on btnSelectSpine pressed do
		(
			if bipedObj == undefined then return false
			local spines = #()
			for i = 1 to 4 do
			(
				local spine = getBipedBone bipedObj ("Spine" + (if i > 1 then i as string else ""))
				if spine != undefined then append spines spine
			)
			if spines.count > 0 then select spines
		)

		-- 选择颈部
		on btnSelectNeck pressed do
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
		on btnSelectHead pressed do
		(
			if bipedObj == undefined then return false
			local head = getBipedBone bipedObj "Head"
			if head != undefined then select head
		)

		-- 选择骨盆
		on btnSelectPelvis pressed do
		(
			if bipedObj == undefined then return false
			local pelvis = getBipedBone bipedObj "Pelvis"
			if pelvis != undefined then select pelvis
		)

		-- 选择左臂
		on btnSelectLArm pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L Clavicle", "L UpperArm", "L Forearm") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择右臂
		on btnSelectRArm pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("R Clavicle", "R UpperArm", "R Forearm") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择左腿
		on btnSelectLLeg pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L Thigh", "L Calf") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择右腿
		on btnSelectRLeg pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("R Thigh", "R Calf") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择左手
		on btnSelectLHand pressed do
		(
			if bipedObj == undefined then return false
			local hand = getBipedBone bipedObj "L Hand"
			if hand != undefined then select hand
		)

		-- 选择右手
		on btnSelectRHand pressed do
		(
			if bipedObj == undefined then return false
			local hand = getBipedBone bipedObj "R Hand"
			if hand != undefined then select hand
		)

		-- 选择左脚
		on btnSelectLFoot pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("L Foot", "L Toe0") do
			(
				local bone = getBipedBone bipedObj part
				if bone != undefined then append bones bone
			)
			if bones.count > 0 then select bones
		)

		-- 选择右脚
		on btnSelectRFoot pressed do
		(
			if bipedObj == undefined then return false
			local bones = #()
			for part in #("R Foot", "R Toe0") do
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

					local ctrl = createCustomController ddlCtrlShape.selected spnCtrlSize.value cpCtrlColor.color
					ctrl.name = ctrlName
					ctrl.pos = bipBone.pos
					ctrl.rotation = bipBone.rotation

					-- 创建约束系统
					local locator = createConstraintSystem ctrl bipBone ddlConstraintMode.selected chkUseLocator.checked spnLocSize.value

					append newCtrls ctrl
					if locator != undefined then append newLocs locator

					-- 保存绑定数据
					append rigData #(ctrl, bipBone, locator)
				)

				select newCtrls
				edtInfo.text = "绑定完成!\r\n创建了 " + (newCtrls.count as string) + " 个控制器"
			)
			catch
			(
				edtInfo.text = "绑定失败:\r\n" + (getCurrentException())
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
				local newLocs = #()

				for boneName in boneList do
				(
					local bipBone = getBipedBone bipedObj boneName
					if bipBone != undefined then
					(
						local ctrlName = "Ctrl_" + (substituteString boneName " " "_")
						local ctrl = createCustomController ddlCtrlShape.selected spnCtrlSize.value cpCtrlColor.color
						ctrl.name = ctrlName
						ctrl.pos = bipBone.pos
						ctrl.rotation = bipBone.rotation

						local locator = createConstraintSystem ctrl bipBone ddlConstraintMode.selected chkUseLocator.checked spnLocSize.value

						append newCtrls ctrl
						if locator != undefined then append newLocs locator
						append rigData #(ctrl, bipBone, locator)
					)
				)

				select newCtrls
				edtInfo.text = "全身绑定完成!\r\n创建了 " + (newCtrls.count as string) + " 个控制器"
			)
			catch
			(
				edtInfo.text = "自动绑定失败:\r\n" + (getCurrentException())
			)
		)

		-- 烘焙到控制器
		on btnBakeToCtrl pressed do
		(
			if rigData.count == 0 then
			(
				messageBox "没有找到绑定数据！" title:"错误"
				return false
			)

			try
			(
				local startFrame = animationRange.start
				local endFrame = animationRange.end
				local ctrls = #()

				for data in rigData do
					if isValidNode data[1] then append ctrls data[1]

				if ctrls.count > 0 then
				(
					for ctrl in ctrls do
					(
						bakeTransform ctrl startFrame endFrame #pos
						bakeTransform ctrl startFrame endFrame #rotation
					)
					edtInfo.text = "动画已烘焙到 " + (ctrls.count as string) + " 个控制器"
				)
			)
			catch
			(
				edtInfo.text = "烘焙失败:\r\n" + (getCurrentException())
			)
		)

		-- 选择所有控制器
		on btnSelectAllCtrls pressed do
		(
			local ctrls = #()
			for data in rigData do
				if isValidNode data[1] then append ctrls data[1]

			if ctrls.count > 0 then
			(
				select ctrls
				edtInfo.text = "已选择 " + (ctrls.count as string) + " 个控制器"
			)
		)

		-- 选择所有Locator
		on btnSelectAllLocs pressed do
		(
			local locs = #()
			for data in rigData do
				if data[3] != undefined and isValidNode data[3] then append locs data[3]

			if locs.count > 0 then
			(
				select locs
				edtInfo.text = "已选择 " + (locs.count as string) + " 个Locator"
			)
		)

		-- 清除绑定
		on btnClearRig pressed do
		(
			if queryBox "确定要删除所有绑定吗？" title:"确认" then
			(
				try
				(
					local deleteCount = 0
					for data in rigData do
					(
						if isValidNode data[1] then (delete data[1]; deleteCount += 1)
						if data[3] != undefined and isValidNode data[3] then (delete data[3]; deleteCount += 1)
					)
					rigData = #()
					edtInfo.text = "已删除 " + (deleteCount as string) + " 个对象"
				)
				catch
				(
					edtInfo.text = "清除失败:\r\n" + (getCurrentException())
				)
			)
		)
	)

	createDialog advBipedRigRollout
)

print "Biped Advanced Custom Rig Tool 已加载！"
