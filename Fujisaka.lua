--Fujisaka.lua
--Server script written to move Fujisaka ShuttleBox in Nijinohara New Transit game along a set of predefined nodes using 
--tweenservice, aiming to use as an alternative method to physics based methods. 
--moveBetweenNodes() contains alteration made by ChatGPT during production phase

-- Services
local TweenService = game:GetService("TweenService")

-- References
local minecart = script.Parent
local primaryPart = script.Parent.Parent.SensorFront
local nodesFolder = workspace:FindFirstChild("Nodes")

if not nodesFolder then
	error("Nodes folder not found in the workspace!")
end

-- Settings
local stopDuration = 15 --Station Dwell Time
local baseSpeed = script.Parent.Speed.Value --Max Speed the train will aim for

-- Node Preload
local function prepareNodes(folder)
	local rawNodes = folder:GetChildren()
	local nodeTable = {}

	for _, node in pairs(rawNodes) do
		local nodeNumber = tonumber(node.Name)
		if nodeNumber then
			local isStation = node:FindFirstChild("IsStation") and true or false
			table.insert(nodeTable, {
				Position = node.Position,
				Orientation = node.CFrame.LookVector,
				IsStation = isStation,
				Number = nodeNumber,
			})
		else
			warn("Node " .. node.Name .. " is not numerically named. Ignoring.")
		end
	end

	table.sort(nodeTable, function(a, b)
		return a.Number < b.Number
	end)

	return nodeTable
end

--Table reverse helper
local function reverseTable(tbl)
	local reversed = {}
	for i = #tbl, 1, -1 do
		table.insert(reversed, tbl[i])
	end
	return reversed
end

-- Calculate travel time
local function calculateTravelTime(distance, speed)
	return distance / speed
end


-- Move the minecart's PrimaryPart between two nodes
-- Adjusted to dynamically modify speed near the last node
local function moveBetweenNodes(startNode, endNode, isFirst, isFinal)
	local distance = (startNode.Position - endNode.Position).Magnitude
	local speed = baseSpeed

	if isFinal then
		speed = baseSpeed / 2 -- Slow down for the final approach
	end

	local travelTime = calculateTravelTime(distance, speed)

	-- Choose easing based on first or final node
	local tweenInfo
	if isFirst then
		tweenInfo = TweenInfo.new(
			travelTime, 
			Enum.EasingStyle.Sine, 
			Enum.EasingDirection.In 
		)
	elseif isFinal then
		tweenInfo = TweenInfo.new(
			travelTime, 
			Enum.EasingStyle.Sine, 
			Enum.EasingDirection.Out 
		)
	else
		tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear) -- Regular movement between nodes
	end

	-- Create the tween goal using CFrame
	local targetCFrame = CFrame.new(endNode.Position, endNode.Position + endNode.Orientation)
	local tweenGoal = { CFrame = targetCFrame }
	local tween = TweenService:Create(primaryPart, tweenInfo, tweenGoal)

	-- Play the tween
	tween:Play()
	tween.Completed:Wait()

	-- Ensure the minecart aligns precisely with the endpoint
	primaryPart.CFrame = targetCFrame
end




-- Main loop: Traverse nodes and reverse direction
local function mainLoop(nodes)
	local forward = true -- Dirflag

	while true do
		local nodeList = forward and nodes or reverseTable(nodes)

		-- Move from start node to the end node
		for i = 1, #nodeList - 1 do
			local currentNode = nodeList[i]
			local nextNode = nodeList[i + 1]

			-- Mark the first and final nodes
			local isFirst = (i == 1) -- First node in the segment
			local isFinal = (i == #nodeList - 1) -- Final node in the segment

			moveBetweenNodes(currentNode, nextNode, isFirst, isFinal)
		end

		-- Stop at the end node
		local endNode = nodeList[#nodeList]
		script.Parent.Parent.PlayerWeld.WeldStart.Value = false
		script.Parent.Parent.Doors.LeftDoorOpen.Value = true
		script.Parent.Parent.RunningForward.Value = not script.Parent.Parent.RunningForward.Value --temporary tasks
		wait(stopDuration) 
		script.Parent.Parent.PlayerWeld.WeldStart.Value = true

		-- Reverse direction and go back to start
		forward = not forward
		wait(stopDuration) 
	end
end






-- Initialize the minecart at the starting position
local function initializeMinecart(startNode, nodes)
	-- Set the PrimaryPart's CFrame to the first node's position and orientation
	if #nodes > 1 then
		local nextNode = nodes[2]
		primaryPart.CFrame = CFrame.new(startNode.Position, startNode.Position + nextNode.Orientation)
	else
		primaryPart.CFrame = CFrame.new(startNode.Position)
	end
end

-- Script Execution
local nodes = prepareNodes(nodesFolder)

if not nodes or #nodes < 2 then
	error("Node preparation failed. Ensure at least 2 valid nodes exist in workspace.Nodes.")
end

-- Initialize the minecart at the first node
local startingNode = nodes[1]
initializeMinecart(startingNode, nodes)

-- Start the main loop
mainLoop(nodes)
