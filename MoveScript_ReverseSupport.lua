local TRAIN_MODEL = script.Parent.Parent
local PRIMARY_PART = TRAIN_MODEL.PrimaryPart
local THROTTLE = TRAIN_MODEL.PrimaryPart:WaitForChild("Throttle")        -- NumberValue
local DIRECTION = TRAIN_MODEL.PrimaryPart:WaitForChild("Direction")      -- IntValue

-- Configuration
local TRACK_NODES = workspace:WaitForChild("TrackNodes")
local NODE_PREFIX = "" --Leave this empty if using Number-only node names
local MIN_NODE_DISTANCE = 1
local MAX_SPEED = 100
local LOOP_PATH = false --Does the train go back to the first node after reaching the last? Does not work the same as reverse. 

-- Runtime
local currentSpeed = 0
local currentNodeIndex = 1
local targetDirection = nil

-- Load nodes
local function getOrderedNodes()
	local nodes = {}
	local i = 1
	while true do
		local node = TRACK_NODES:FindFirstChild(NODE_PREFIX .. tostring(i))
		if not node then break end
		table.insert(nodes, node)
		i += 1
	end
	return nodes
end

local nodes = getOrderedNodes()
local totalNodes = #nodes

if totalNodes < 2 then
	warn("Not enough path nodes found.")
	return
end --You have to go somewhere

game:GetService("RunService").Heartbeat:Connect(function(dt)
	local throttle = THROTTLE.Value
	local directionFlag = DIRECTION.Value

	if directionFlag == 0 then
		return
	end

	if currentSpeed <= 0 and throttle < 0 and directionFlag ~= -1 then
		currentSpeed = 0
		throttle = 0
	end

	-- Apply acceleration
	currentSpeed += throttle * dt
	currentSpeed = math.clamp(currentSpeed, 0, MAX_SPEED)

	local currentPos = PRIMARY_PART.Position
	local targetNode = nodes[currentNodeIndex]
	if not targetNode then
		currentSpeed = 0
		return
	end

	local toTarget = targetNode.Position - currentPos
	local distance = toTarget.Magnitude

	-- Advance or reverse node
	local nodeChanged = false
	if distance < MIN_NODE_DISTANCE then
		if directionFlag == 1 then
			if currentNodeIndex < totalNodes then
				currentNodeIndex += 1
				nodeChanged = true
			elseif LOOP_PATH then
				currentNodeIndex = 1
				nodeChanged = true
			else
				currentSpeed = 0
				return
			end
		elseif directionFlag == -1 then
			if currentNodeIndex > 1 then
				currentNodeIndex -= 1
				nodeChanged = true
			elseif LOOP_PATH then
				currentNodeIndex = totalNodes
				nodeChanged = true
			else
				currentSpeed = 0
				return
			end
		end
	end

	targetNode = nodes[currentNodeIndex]
	local toNext = targetNode.Position - currentPos
	local moveDirection = toNext.Unit
	local moveDelta = moveDirection * currentSpeed * dt
	local newPos = currentPos + moveDelta

	-- Target facing direction
	local desiredLook = moveDirection
	local currentLook = PRIMARY_PART.CFrame.LookVector
	local smoothedLook = currentLook:Lerp(desiredLook, dt * 5) --To ensure that the rotation is smooth.
	local newCFrame = CFrame.new(newPos, newPos + smoothedLook)

	PRIMARY_PART.CFrame = newCFrame
end)