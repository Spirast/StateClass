local ssm = require(game:GetService("ReplicatedStorage").Shared.SSM)
local StateManager = ssm.new()

local walkspeed = 0

task.spawn(function()
    while task.wait(1) do
        print(walkspeed)
    end
end)


StateManager:Define("Running", function()
    -- change walkspeed to 50

    walkspeed = 50
    StateManager:ChangeState("Waiting")
    return
end)

StateManager:Define("Waiting", function()
    print("hi")
    return
end)

StateManager:Define("Walking", function()
    -- walk towards something
    StateManager:DisableDefinition("Waiting")

    task.wait(5) -- simulate calculations or something

    StateManager:ChangeState("Running")
    return
end)

StateManager:Start()

StateManager:ChangeState("Walking")