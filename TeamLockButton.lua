local function isPlayerInOperations(player)
	return player.Team and player.Team.Name == "Operation" --change this to your own
end

Button.MouseClick:Connect(function(player)
	if not isPlayerInOperations(player) then
		print("Not eligible")
		return
	end
    print("Button Used")
end)