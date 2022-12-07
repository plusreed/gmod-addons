simpleadmin = {}

simpleadmin.__version = "1.0.0"
simpleadmin.__prefix = "./"

-- TODO: Use SteamID64s here instead
simpleadmin.owners = {
    -- "STEAM_0:0:55942095" -- meeeee :3
}

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
        return
    end

    self.callback(ply, args, ...)
end

simpleadmin.commands = {}

-- help command
simpleadmin.commands.help = simpleadmin.Command.new("help", simpleadmin.Permission.ALL, function (ply, arg)
    local isOwner = simpleadmin.isOwner(ply)

    for _, v in pairs(simpleadmin.commands) do
        if v.permission == simpleadmin.Permission.OWNER and not isOwner then
            continue
        end

        ply:ChatPrint(v.name .. " - " .. v.help)
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
    elseif arg[1] == "off" then
        target:GodDisable()
        ply:ChatPrint("God mode disabled for " .. target:Nick() .. "!")
    else
        ply:ChatPrint("Invalid argument!")
    end
end, "Enable god mode for a player.")

-- chat handler
hook.Add("PlayerSay", "simpleadmin", function (ply, text, team)
    --ply:ChatPrint(text:sub(1, 2))
    if text:sub(1, 2) ~= simpleadmin.__prefix then
        return text
    end

    local args = string.Explode(" ", text:sub(3))
    local cmd = args[1]
    table.remove(args, 1)

    --ply:ChatPrint("running cmd: " .. cmd)

    if simpleadmin.commands[cmd] then
        simpleadmin.commands[cmd]:run(ply, args)
    else
        ply:ChatPrint("Command not found!")
    end

    return ""
end)