simpleadmin = {}

simpleadmin.__version = "1.0.0"
simpleadmin.__prefix = "./"

-- TODO: Use SteamID64s here instead
simpleadmin.owners = {
    -- "STEAM_0:0:55942095" -- meeeee :3
}

-- TODO: should these be under a "class"?
function simpleadmin.isOwner(ply)
    for k, v in pairs(simpleadmin.owners) do
        if ply:SteamID() == v then
            return true
        end
    end
    return false
end

function simpleadmin.findByNick(nickname)
    -- get rid of quotes if present.
    if nickname:sub(1, 1) == "\"" and nickname:sub(-1) == "\"" then
        nickname = nickname:sub(2, -2)
    end

    for _, v in pairs(player.GetAll()) do
        if v:Nick() == nickname then
            return v
        end
    end
    return nil
end

-- Permission enum for commands.
simpleadmin.Permission = {
    OWNER = "owner",
    ALL = "all"
}

simpleadmin.Feature = {}
simpleadmin.Feature.__index = simpleadmin.Feature

-- Feature class, used to create features.
-- Should have a name, and a bool which determines if it is enabled or not.
function simpleadmin.Feature.new(name, enabled)
    if type(name) ~= "string" then
        error("Invalid feature name: " .. tostring(name))
    end

    if type(enabled) ~= "boolean" then
        error("Invalid feature enabled: " .. tostring(enabled))
    end

    local self = setmetatable({}, simpleadmin.Feature)
    self.name = name
    self.enabled = enabled
    return self
end

simpleadmin.features = {}

function simpleadmin.featureEnabled(name) 
    local target = nil

    for _, v in pairs(simpleadmin.features) do
        if v.name == name then
            target = v
            break
        end
    end

    if not target then
        return false
    end

    return target.enabled
end

-- Feature to pop up a message when god mode enabled for a person.
simpleadmin.features.god_hud = simpleadmin.Feature.new("god_hud", true)
simpleadmin.features.kill_players_when_they_use_my_commands = simpleadmin.Feature.new("kill_players_when_they_use_my_commands", true)

simpleadmin.Command = {}
simpleadmin.Command.__index = simpleadmin.Command

function simpleadmin.Command.new(name, permission, callback, help)
    if type(name) ~= "string" then
        error("Invalid command name: " .. tostring(name))
    end

    if type(callback) ~= "function" then
        error("Invalid command callback: " .. tostring(callback))
    end

    if type(help) ~= "string" then
        error("Invalid command help: " .. tostring(help))
    end

    local self = setmetatable({}, simpleadmin.Command)
    self.name = name
    self.permission = permission
    self.callback = callback
    self.help = help
    return self
end

function simpleadmin.Command:run(ply, args, ...)
    if self.permission == simpleadmin.Permission.OWNER and not simpleadmin.isOwner(ply) then
        ply:ChatPrint("You do not have permission to run this command")
        
        if simpleadmin.featureEnabled("kill_players_when_they_use_my_commands") then
            -- kill after 2 seconds
            timer.Simple(2, function ()
                ply:Kill()
                ply:ChatPrint("lol. lmao")
            end)
        end

        return
    end

    self.callback(ply, args, ...)
end

simpleadmin.commands = {}

-- help command
simpleadmin.commands.help = simpleadmin.Command.new("help", simpleadmin.Permission.ALL, function (ply, arg)
    local isOwner = simpleadmin.isOwner(ply)

    ply:ChatPrint("SimpleAdmin commands (that you have access to):")
    for _, v in pairs(simpleadmin.commands) do
        if v.permission == simpleadmin.Permission.OWNER and not isOwner then
            continue
        end

        ply:ChatPrint("  " .. v.name .. " - " .. v.help)
    end
end, "Show this help message.")

-- impersonate command, command should go like ./impersonate <player nickname> <message>
simpleadmin.commands.impersonate = simpleadmin.Command.new("impersonate", simpleadmin.Permission.OWNER, function (ply, arg)
    -- find player by nickname
    local target = simpleadmin.findByNick(arg[1])

    if not target then
        ply:ChatPrint("Player not found!")
        return
    end

    -- remove player name from args
    table.remove(arg, 1)

    -- send message
    target:Say(table.concat(arg, " "))
end, "Impersonate a player.")

-- kick command, command should go like ./kick <player nickname> <reason>
simpleadmin.commands.kick = simpleadmin.Command.new("kick", simpleadmin.Permission.OWNER, function (ply, arg)
    -- find player by nickname
    local target = simpleadmin.findByNick(arg[1])

    if not target then
        ply:ChatPrint("Player not found!")
        return
    end

    -- remove player name from args
    table.remove(arg, 1)

    -- kick player
    target:Kick(table.concat(arg, " "))
end, "Kick a player.")

-- god mode command, command should go like ./god <player nickname> <on/off>
simpleadmin.commands.god = simpleadmin.Command.new("god", simpleadmin.Permission.OWNER, function (ply, arg)
    local target = nil

    if arg[1] == "@me" then
        target = ply
    else
        -- find player by nickname
        target = simpleadmin.findByNick(arg[1])

        if not target then
            ply:ChatPrint("Player not found!")
            return
        end
    end

    -- remove player name from args
    table.remove(arg, 1)

    -- set god mode
    if arg[1] == "on" then
        target:GodEnable()
        ply:ChatPrint("God mode enabled for " .. target:Nick() .. "!")

        if simpleadmin.featureEnabled("god_hud") then
            PrintMessage(HUD_PRINTCENTER, target:Nick() .. " is now in god mode!")
        end
    elseif arg[1] == "off" then
        target:GodDisable()
        ply:ChatPrint("God mode disabled for " .. target:Nick() .. "!")

        if simpleadmin.featureEnabled("god_hud") then
            PrintMessage(HUD_PRINTCENTER, target:Nick() .. " is no longer in god mode.")
        end
    else
        ply:ChatPrint("Invalid argument!")
    end
end, "Enable god mode for a player.")

-- Command to toggle features (from the feature table), should look like this: ./feature <feature name> <on/off>
simpleadmin.commands.feature = simpleadmin.Command.new("feature", simpleadmin.Permission.OWNER, function (ply, arg)
    local target = nil

    -- find feature by name
    for _, v in pairs(simpleadmin.features) do
        if v.name == arg[1] then
            target = v
            break
        end
    end

    if not target then
        ply:ChatPrint("Feature not found!")
        return
    end

    -- remove feature name from args
    table.remove(arg, 1)

    -- set feature state
    if arg[1] == "on" then
        target.enabled = true
        ply:ChatPrint("Feature " .. target.name .. " enabled!")
    elseif arg[1] == "off" then
        target.enabled = false
        ply:ChatPrint("Feature " .. target.name .. " disabled!")
    else
        ply:ChatPrint("Feature " .. target.name .. " is currently set to: " .. tostring(target.enabled))
    end
end, "Toggle features.")

-- chat handler
hook.Add("PlayerSay", "simpleadmin", function (ply, text, team)
    if text:sub(1, 2) ~= simpleadmin.__prefix then
        return text
    end

    local args = string.Explode(" ", text:sub(3))
    local cmd = args[1]
    table.remove(args, 1)

    if simpleadmin.commands[cmd] then
        simpleadmin.commands[cmd]:run(ply, args)
    else
        ply:ChatPrint("Command not found!")
    end

    return ""
end)