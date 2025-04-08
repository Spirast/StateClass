--[[
    Spirast State Manager (SSM)
    
    A finite state machine implementation for Luau that manages state transitions and actions.
    Provides methods to define, manage, and execute state-based behaviors with support for
    enabling/disabling states, changing definitions, and handling state transitions.
    
    Usage:
        local stateMachine = SSM.new(character)
        stateMachine:Define("idle", function(self) -- idle behavior end)
        stateMachine:Start()
        stateMachine:ChangeState("idle")

    @spirast
]]

-- Types
export type SSMObject = {
    State: string?,
    Actions: {[string]: Definition},
    Running: boolean,
    _stateChangedSignal: BindableEvent?,
    _stateChangedConnection: RBXScriptConnection?,
    _processingState: boolean?,
    _currentTask: thread?, -- Added to track the current running task
    
    Start: (self: SSMObject) -> (),
    Stop: (self: SSMObject) -> (),
    Pause: (self: SSMObject, time: number) -> (),
    Define: (self: SSMObject, state: string, callback: ((self: SSMObject, ...any) -> any)?) -> (),
    DisableDefinition: (self: SSMObject, state: string) -> (),
    ReEnableDefinition: (self: SSMObject, state: string) -> (),
    DestroyDefinition: (self: SSMObject, state: string) -> (),
    ChangeDefinition: (self: SSMObject, state: string, callback: ((self: SSMObject, ...any) -> any)?) -> (),
    DefinitionIsRunning: (self: SSMObject, state: string) -> boolean,
    ChangeState: (self: SSMObject, newState: string) -> boolean,
    Destroy: (self: SSMObject) -> ()
}

export type Definition = {
    Running: boolean,
    funct: ((self: SSMObject, ...any) -> any)?,
    Disabled: boolean,
}

-- Class
local SSM = {}
SSM.__index = SSM

--[[
    Creates a new SSM (Spirast State Machine) instance.
    
    @param character Model - The character model to associate with the state machine
    @return SSMObject - A new state machine instance with initialized properties
]]
function SSM.new() : SSMObject
    local self = setmetatable({}, SSM)

    self.State = nil
    self.Actions = {}
    self.Running = false
    self._processingState = false
    self._currentTask = nil -- Initialize the task tracker
    self._stateChangedSignal = Instance.new("BindableEvent")
    
    self._stateChangedConnection = self._stateChangedSignal.Event:Connect(function(newState)
        if not self.Running then return end
        
        if self.Actions[newState] and not self.Actions[newState].Disabled then
            self.Actions[newState].Running = true
            if self.Actions[newState].funct then
                self._processingState = true
                
                -- Cancel previous task if it exists
                if self._currentTask then
                    task.cancel(self._currentTask)
                    self._currentTask = nil
                end
                
                -- Spawn new task for the state function
                self._currentTask = task.spawn(function()
                    self.Actions[newState].funct(self)
                end)
                
                self._processingState = false
            end
        end
    end)

    return self
end

--[[
    Starts the state machine if it's not already running.
    
    Activates the current state and executes its associated function
    if the state exists, is not disabled, and has a function defined.
    
    @return void
]]
function SSM:Start()
    if self.Running then return end
    
    self.Running = true
    
    if self.State and self.Actions[self.State] and not self.Actions[self.State].Disabled then
        self.Actions[self.State].Running = true
        if self.Actions[self.State].funct then
            self._processingState = true
            
            -- Cancel previous task if it exists
            if self._currentTask then
                task.cancel(self._currentTask)
                self._currentTask = nil
            end
            
            -- Spawn new task for the state function
            self._currentTask = task.spawn(function()
                self.Actions[self.State].funct(self)
            end)
            
            self._processingState = false
        end
    end
end

--[[
    Stops the state machine if it's currently running.
    
    Sets the running state to false, marks the current state's action
    as not running if a state exists and has an associated action,
    and cancels any running task.
    
    @return void
]]
function SSM:Stop()
    if not self.Running then return end
    
    self.Running = false
    
    -- Cancel current task if it exists
    if self._currentTask then
        task.cancel(self._currentTask)
        self._currentTask = nil
    end
    
    if self.State and self.Actions[self.State] then
        self.Actions[self.State].Running = false
    end
end

--[[
    Pauses the state machine for a specified amount of time.
    
    Stops the state machine temporarily and restarts it after the given time period.
    
    @param time number - The duration in seconds to pause the state machine
    @return void
]]
function SSM:Pause(time: number)
    if not self.Running then return end
    
    self:Stop()
    
    task.delay(time, function()
        self:Start()
    end)
end

--[[
    Defines a new state with an associated callback function.
    
    @param state string - The name of the state to define
    @param callback function - Optional function to execute when this state is active
    @return void
]]
function SSM:Define(state: string, callback: ((self: SSMObject, ...any) -> any?)?): ()
    self.Actions[state] = {
        Running = false,
        funct = callback,
        Disabled = false,
    }
end

--[[
    Disables a state definition, preventing it from being executed.
    
    @param state string - The name of the state to disable
    @return void
]]
function SSM:DisableDefinition(state: string)
    if self.Actions[state] then
        self.Actions[state].Disabled = true
    end
end

--[[
    Re-enables a previously disabled state definition.
    
    @param state string - The name of the state to re-enable
    @return void
]]
function SSM:ReEnableDefinition(state: string)
    if self.Actions[state] then
        self.Actions[state].Disabled = false
    end
end

--[[
    Completely removes a state definition from the state machine.
    
    @param state string - The name of the state to destroy
    @return void
]]
function SSM:DestroyDefinition(state: string)
    if self.Actions[state] then
        self.Actions[state] = nil
    end
end

--[[
    Changes the callback function for an existing state definition.
    
    @param state string - The name of the state to modify
    @param callback function - The new function to execute when this state is active
    @return void
]]
function SSM:ChangeDefinition(state: string, callback: ((self: SSMObject, ...any) -> any)?)
    if self.Actions[state] then
        self.Actions[state].funct = callback
    end
end

--[[
    Checks if a specific state definition is currently running.
    
    @param state string - The name of the state to check
    @return boolean - True if the state is running, false otherwise
]]
function SSM:DefinitionIsRunning(state: string): boolean
    if self.Actions[state] then
        return self.Actions[state].Running
    else
        return false
    end
end

--[[
    Changes the current state of the state machine.
    
    Stops the current state if one exists, sets the new state,
    and fires the state changed signal to trigger the new state's function.
    
    @param newState string - The name of the state to change to
    @return boolean - True if the state change was successful, false if the state doesn't exist
]]
function SSM:ChangeState(newState: string): boolean
    if not self.Actions[newState] then
        return false
    end
    
    if self.State and self.Actions[self.State] then
        self.Actions[self.State].Running = false
    end
    
    -- Cancel current task if it exists
    if self._currentTask then
        task.cancel(self._currentTask)
        self._currentTask = nil
    end
    
    self.State = newState
    self._stateChangedSignal:Fire(newState)
    
    return true
end

--[[
    Cleans up the state machine by stopping it, disconnecting events,
    and clearing all state definitions.
    
    Should be called when the state machine is no longer needed to prevent memory leaks.
    
    @return void
]]
function SSM:Destroy()
    self:Stop()
    
    if self._stateChangedConnection then
        self._stateChangedConnection:Disconnect()
        self._stateChangedConnection = nil
    end
    
    if self._stateChangedSignal then
        self._stateChangedSignal:Destroy()
        self._stateChangedSignal = nil
    end
    
    self.Actions = {}
    self.State = nil
end

return SSM
