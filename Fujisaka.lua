-- Services
local TweenService = game:GetService("TweenService")

-- References
local Train = script.Parent
local primaryPart = script.Parent.Parent.SensorFront
local nodesFolder = workspace.Nodes

-- Settings
local stopDuration = 15 -- Time to stop at start and end nodes (in seconds)
local baseSpeed = script.Parent.Speed.Value --Base speed for train studs per second
local accelerationDuration = 3 -- max no of allowed nodes to use for acceleration
local decelerationDuration = 4 -- Number of nodes before the last one to decelerate
local decelThreshold = decelerationDuration -- Also used for triggering deceleration sound

-- Prepares node data
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

-- Reverse the node table to travel the other way round
local function reverseTable(tbl)
	local reversed = {}
	for i = #tbl, 1, -1 do
		table.insert(reversed, tbl[i])
	end
	return reversed
end

-- Elementary math
local function calculateTravelTime(distance, speed)
	return distance / speed
end

-- Move PrimaryPart between two nodes
local function moveBetweenNodes(startNode, endNode, currentSpeed, isFirst, isFinal)
	local distance = (startNode.Position - endNode.Position).Magnitude
	local travelTime = calculateTravelTime(distance, currentSpeed)

	-- Choose easing based on first or final node
	local tweenInfo
	if isFirst then
		tweenInfo = TweenInfo.new(
			travelTime,
			Enum.EasingStyle.Sine, -- Sine easing for smooth acceleration
			Enum.EasingDirection.In -- Accelerates from a stop
		)
	elseif isFinal then
		tweenInfo = TweenInfo.new(
			travelTime,
			Enum.EasingStyle.Sine, -- Quint easing for smooth deceleration
			Enum.EasingDirection.Out -- Decelerates towards the end
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

	-- Ensure the Train aligns precisely with the endpoint
	primaryPart.CFrame = targetCFrame
end

-- Main loop: Traverse nodes and reverse direction
local function mainLoop(nodes)
	local forward = true -- Direction flag

	while true do
		local nodeList = forward and nodes or reverseTable(nodes)
		local currentSpeed = 0 -- Initial speed for acceleration
		local runSound = script.Parent.RunSound 

		-- Move from start node to the end node
		for i = 1, #nodeList - 1 do
			local currentNode = nodeList[i]
			local nextNode = nodeList[i + 1]

			-- Mark the first and final nodes
			local isFirst = (i == 1) -- First node in the segment
			local isFinal = (i == #nodeList - 1) -- Final node in the segment

			-- Handle acceleration phase
			if i <= accelerationDuration then
				local progress = i / accelerationDuration
				currentSpeed = baseSpeed * progress

				-- Play Accel sound
				local accelSound = script.Parent.Accel
				if accelSound and not accelSound.IsPlaying then
					accelSound:Play()
				end

				-- Stop RunSound
				if runSound and runSound.IsPlaying then
					runSound:Stop()
				end
			elseif i >= (#nodeList - decelerationDuration) then
				-- Handle deceleration phase
				local progress = (#nodeList - i) / decelerationDuration
				currentSpeed = baseSpeed * progress

				-- Play Decel sound
				local decelSound = script.Parent.Decel
				if decelSound and not decelSound.IsPlaying then
					decelSound:Play()
				end

				-- Stop RunSound
				if runSound and runSound.IsPlaying then
					runSound:Stop()
				end
			else
				-- Constant speed in the middle
				currentSpeed = baseSpeed

				-- Play RunSound
				if runSound and not runSound.IsPlaying then
					runSound:Play()
				end

				-- Stop other sounds
				local accelSound = script.Parent.Accel
				local decelSound = script.Parent.Decel
				if accelSound and accelSound.IsPlaying then
					accelSound:Stop()
				end
				if decelSound and decelSound.IsPlaying then
					decelSound:Stop()
				end
			end

			-- Move between nodes with dynamic speed
			moveBetweenNodes(currentNode, nextNode, currentSpeed, isFirst, isFinal)
		end

		-- Stop at the end node
		local endNode = nodeList[#nodeList]
		script.Parent.Parent.PlayerWeld.WeldStart.Value = false
		script.Parent.Parent.Doors.LeftDoorOpen.Value = true
		script.Parent.Parent.RunningForward.Value = not script.Parent.Parent.RunningForward.Value
		wait(stopDuration) -- Wait at the end node for stop duration
		script.Parent.Parent.PlayerWeld.WeldStart.Value = true

		-- Reverse direction and go back to start
		forward = not forward
		wait(stopDuration) -- Wait at the end/start before reversing
	end
end


-- Vehicle Init
local function initializeTrain(startNode, nodes)
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

-- Initialize the Train at the first node
local startingNode = nodes[1]
initializeTrain(startingNode, nodes)

-- Start the main loop
mainLoop(nodes)
