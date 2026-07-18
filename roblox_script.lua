local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			print(player.Name .. " has been eliminated.")
		end)
	end)

	print("Welcome to the game, " .. player.Name .. "!")
end)
