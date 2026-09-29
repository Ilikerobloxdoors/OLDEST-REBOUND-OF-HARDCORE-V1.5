-- XENO GITHUB MODEL LOADER (.rbxm / .rbxmx)
local G = getgenv()

G.LoadGithubModel = function(url, retryCount, retryDelay)
    retryCount = retryCount or 0
    retryDelay = retryDelay or 1

    if retryCount >= 3 then
        warn("Failed to load model after 3 attempts")
        return nil
    end

    if not (writefile and getcustomasset and request and isfile and delfile) then
        warn("Missing required functions: writefile, getcustomasset, request, isfile, delfile")
        return nil
    end

    local function getHash(str)
        local hash = 0
        for i = 1, #str do
            hash = (hash * 31 + string.byte(str, i)) % 2^32
        end
        return tostring(hash)
    end

    local fileName = "rebound_" .. getHash(url) .. ".rbxm"

    if retryCount > 0 then
        print("Retry " .. retryCount .. ": Cleaning up...")

        pcall(function()
            if isfile(fileName) then
                delfile(fileName)
            end
        end)

        task.wait(retryDelay)
    end

    local fileExists = false

    local fileCheckSuccess, fileExistsResult = pcall(function()
        return isfile(fileName)
    end)

    if fileCheckSuccess and fileExistsResult then
        fileExists = true
    end

    if not fileExists then
        print("Downloading model from: " .. url)

        local response = request({
            Url = url,
            Method = "GET"
        })

        if not response or response.StatusCode ~= 200 then
            warn(
                "Download failed (HTTP " ..
                tostring(response and response.StatusCode or "unknown") ..
                "), retrying..."
            )

            return G.LoadGithubModel(
                url,
                retryCount + 1,
                retryDelay
            )
        end

        writefile(fileName, response.Body)

        print("File saved: " .. fileName)
    end

    local assetSuccess, assetId = pcall(function()
        return getcustomasset(fileName)
    end)

    if not assetSuccess or not assetId then
        warn("getcustomasset failed: " .. tostring(assetId))

        pcall(function()
            if isfile(fileName) then
                delfile(fileName)
            end
        end)

        return G.LoadGithubModel(
            url,
            retryCount + 1,
            retryDelay
        )
    end

    local success, result = pcall(function()
        local objects = game:GetObjects(assetId)

        if objects and #objects > 0 then
            return objects[1]
        end

        return nil
    end)

    if success and result then
        local cloneSuccess, cloned = pcall(function()
            return result:Clone()
        end)

        if cloneSuccess and cloned then
            print("Model loaded and cloned successfully")
            return cloned
        end

        warn("Clone failed: " .. tostring(cloned))
    else
        warn("Failed to load model: " .. tostring(result))
    end

    pcall(function()
        if isfile(fileName) then
            delfile(fileName)
        end
    end)

    return G.LoadGithubModel(
        url,
        retryCount + 1,
        retryDelay
    )
end


G.LoadGithubAudio = function(url, forceRefresh)
    if not (writefile and getcustomasset and request and isfile) then
        warn("Missing required functions")
        return nil
    end

    forceRefresh = forceRefresh or false

    local function getHash(str)
        local hash = 0

        for i = 1, #str do
            hash = (hash * 31 + string.byte(str, i)) % 2^32
        end

        return tostring(hash)
    end

    local function getAudioFormat(audioUrl)
        if audioUrl:match("%.mp3$") then
            return "mp3"
        elseif audioUrl:match("%.ogg$") then
            return "ogg"
        elseif audioUrl:match("%.wav$") then
            return "wav"
        else
            return "mp3"
        end
    end

    local audioFormat = getAudioFormat(url)

    local fileName =
        "rebound_audio_" ..
        getHash(url) ..
        "." ..
        audioFormat

    if forceRefresh and isfile(fileName) and delfile then
        pcall(function()
            delfile(fileName)
        end)
    end

    local fileExists = isfile(fileName)

    if not fileExists then
        print("Downloading audio from: " .. url)

        local downloadUrl =
            url ..
            "?t=" ..
            math.random(1, 100000)

        local response = request({
            Url = downloadUrl,
            Method = "GET",
            Headers = {
                ["Accept"] =
                    "audio/mpeg, audio/ogg, application/octet-stream"
            }
        })

        if not response or response.StatusCode ~= 200 then
            warn(
                "Failed to download audio. Status: " ..
                tostring(response and response.StatusCode or "unknown")
            )

            return nil
        end

        writefile(fileName, response.Body)

        print("Audio saved: " .. fileName)
    end

    local success, assetId = pcall(function()
        return getcustomasset(fileName)
    end)

    if success and assetId then
        return assetId
    end

    pcall(function()
        if delfile and isfile(fileName) then
            delfile(fileName)
        end
    end)

    return nil
end


local function Rebound()

    local repStorage = game.ReplicatedStorage
    local gameData = repStorage.GameData
    local latestRoom = gameData.LatestRoom

    local plusRoom =
        latestRoom.Value + 1

    local currentRooms =
        workspace.CurrentRooms

    local killed = false
    local speed = 2.2
    local entity = nil

    local cameraShaker =
        require(game.ReplicatedStorage.CameraShaker)

    local camera =
        workspace.CurrentCamera

    local camShake =
        cameraShaker.new(
            Enum.RenderPriority.Camera.Value,
            function(cf)
                camera.CFrame =
                    camera.CFrame * cf
            end
        )

    camShake:Start()


    -- =========================================================
    -- NEW REBOUND MODEL
    -- =========================================================

    local rawUrl =
        "https://raw.githubusercontent.com/Ilikerobloxdoors/OLDEST-REBOUND-OF-HARDCORE-V1.5/main/REBOUND%20OLDEST.rbxm"


    if G.LoadGithubModel then

        entity =
            G.LoadGithubModel(rawUrl)

        if entity then
            entity.Parent = workspace
        end
    end


    if not entity then
        warn("Rebound model could not be loaded.")
        return
    end


    -- =========================================================
    -- FIND A PART TO USE AS THE ROOT
    -- =========================================================

    local entityPart =
        entity.PrimaryPart


    -- If the model has no PrimaryPart,
    -- automatically find the first BasePart.
    if not entityPart then

        entityPart =
            entity:FindFirstChildWhichIsA(
                "BasePart",
                true
            )

        if entityPart then
            warn(
                "Rebound model has no PrimaryPart. " ..
                "Using: " ..
                entityPart:GetFullName()
            )
        end
    end


    -- If the downloaded object itself is a BasePart.
    if not entityPart and entity:IsA("BasePart") then
        entityPart = entity
    end


    if not entityPart then

        warn(
            "ERROR: Rebound model contains no BasePart."
        )

        entity:Destroy()

        return
    end


    -- =========================================================
    -- POSITION MODEL
    -- =========================================================

    local function GetLastRoom()
        return currentRooms:FindFirstChild(
            plusRoom
        )
    end


    local targetRoom =
        GetLastRoom()


    if targetRoom then

        local roomEnd =
            targetRoom:FindFirstChild("RoomEnd")

        if roomEnd then
            entityPart.CFrame =
                roomEnd.CFrame
        end

    else

        local currentRoom =
            currentRooms:FindFirstChild(
                tostring(latestRoom.Value)
            )

        if currentRoom then

            local roomEnd =
                currentRoom:FindFirstChild("RoomEnd")

            if roomEnd then
                entityPart.CFrame =
                    roomEnd.CFrame
            end
        end
    end


    entityPart.CanCollide = false
    entityPart.Anchored = true


    -- =========================================================
    -- MOVING SOUND
    -- =========================================================

    task.wait(4)

    local rebmoving =
        G.LoadGithubAudio(
            "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/MovingRebound.mp3"
        )


    local moving =
        Instance.new("Sound")

    moving.SoundId =
        rebmoving or ""

    moving.Parent =
        entityPart

    moving.Volume = 10

    moving:Play()


    -- =========================================================
    -- PLAYER DETECTION
    -- =========================================================

    local function canSeeTarget(target, size)

        if killed then
            return
        end

        if not target then
            return false
        end

        local root =
            target:FindFirstChild(
                "HumanoidRootPart"
            )

        if not root then
            return false
        end

        local origin =
            entityPart.Position

        local direction =
            (root.Position - origin).Unit * size

        local ray =
            Ray.new(
                origin,
                direction
            )

        local hit =
            workspace:FindPartOnRay(
                ray,
                entityPart
            )


        if hit then

            if hit:IsDescendantOf(target) then

                killed = true

                return true
            end

        else

            return false
        end

        return false
    end


    -- =========================================================
    -- JUMPSCARE / PLAYER CHECK
    -- =========================================================

    task.spawn(function()

        while entityPart and entity do

            task.wait(0.5)

            local player =
                game.Players.LocalPlayer

            if not player then
                continue
            end

            local character =
                player.Character

            if character then

                local root =
                    character:FindFirstChild(
                        "HumanoidRootPart"
                    )


                if root then

                    if
                        canSeeTarget(
                            character,
                            50
                        )
                        and not character:GetAttribute("Hiding")
                    then

                        moving:Stop()


                        local ReboundJs =
                            Instance.new("ScreenGui")

                        local Static =
                            Instance.new("ImageLabel")

                        local ReboundGui =
                            Instance.new("ImageLabel")

                        local JSSIZE =
                            Instance.new("ImageLabel")


                        ReboundJs.Name =
                            "ReboundJs"

                        ReboundJs.Parent =
                            player:WaitForChild(
                                "PlayerGui"
                            )


                        Static.Name =
                            "Static"

                        Static.Parent =
                            ReboundJs

                        Static.BackgroundTransparency =
                            1

                        Static.Size =
                            UDim2.new(
                                11,
                                0,
                                111,
                                0
                            )

                        Static.Image =
                            "rbxassetid://236543215"

                        Static.ImageTransparency =
                            1


                        ReboundGui.Name =
                            "Rebound"

                        ReboundGui.Parent =
                            ReboundJs

                        ReboundGui.BackgroundTransparency =
                            1

                        ReboundGui.Position =
                            UDim2.new(
                                0.4866,
                                0,
                                0.4793,
                                0
                            )

                        ReboundGui.Size =
                            UDim2.new(
                                0.0267,
                                0,
                                0.0387,
                                0
                            )

                        ReboundGui.Image =
                            "rbxassetid://10914800940"


                        JSSIZE.Name =
                            "JSSIZE"

                        JSSIZE.Parent =
                            ReboundJs

                        JSSIZE.BackgroundTransparency =
                            1

                        JSSIZE.Position =
                            UDim2.new(
                                -0.586,
                                0,
                                -1.251,
                                0
                            )

                        JSSIZE.Size =
                            UDim2.new(
                                2.128,
                                0,
                                3.081,
                                0
                            )

                        JSSIZE.Visible =
                            false

                        JSSIZE.Image =
                            "rbxassetid://10914800940"


                        task.spawn(function()

                            while ReboundJs.Parent do

                                Static.Image =
                                    "rbxassetid://236543215"

                                task.wait(0.002)

                                Static.Rotation = 0

                                task.wait(0.002)

                                Static.Rotation = 180

                                task.wait(0.002)

                                Static.Image =
                                    "rbxassetid://236777652"

                                task.wait(0.002)

                                Static.Rotation = 0

                                task.wait(0.002)

                                Static.Rotation = 180
                            end
                        end)


                        task.spawn(function()

                            local rebjumpscare =
                                G.LoadGithubAudio(
                                    "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/JumpscareReb.mp3"
                                )


                            local jumpscare =
                                Instance.new("Sound")

                            jumpscare.SoundId =
                                rebjumpscare or ""

                            jumpscare.Parent =
                                workspace

                            jumpscare.Volume =
                                5

                            jumpscare:Play()

                            game.Debris:AddItem(
                                jumpscare,
                                10
                            )


                            game.TweenService:Create(
                                Static,
                                TweenInfo.new(0.5),
                                {
                                    ImageTransparency = 0.8
                                }
                            ):Play()


                            game.TweenService:Create(
                                ReboundGui,
                                TweenInfo.new(0.5),
                                {
                                    Size = JSSIZE.Size,
                                    Position = JSSIZE.Position
                                }
                            ):Play()


                            task.spawn(function()

                                task.wait(0.3)

                                local humanoid =
                                    character:FindFirstChildWhichIsA(
                                        "Humanoid"
                                    )

                                if humanoid then
                                    humanoid:TakeDamage(100)
                                end


                                local stats =
                                    game.ReplicatedStorage.GameStats[
                                        "Player_" ..
                                        character.Name
                                    ]


                                if stats then

                                    if stats:FindFirstChild("Total") then

                                        local total =
                                            stats.Total

                                        if total:FindFirstChild("DeathCause") then
                                            total.DeathCause.Value =
                                                "Rebound"
                                        end
                                    end


                                    if stats:FindFirstChild("1") then

                                        local first =
                                            stats["1"]

                                        if first:FindFirstChild("DeathCause") then
                                            first.DeathCause.Value =
                                                "Rebound"
                                        end
                                    end
                                end


                                local deathHint =
                                    game.ReplicatedStorage.Bricks:FindFirstChild(
                                        "DeathHint"
                                    )


                                if deathHint then

                                    firesignal(
                                        deathHint.OnClientEvent,
                                        {
                                            "You died to Rebound...",
                                            "It may trick you by coming through walls or next rooms...",
                                            "Hide when this happens!"
                                        }
                                    )
                                end
                            end)


                            task.wait(0.5)


                            game.TweenService:Create(
                                Static,
                                TweenInfo.new(1),
                                {
                                    ImageTransparency = 1
                                }
                            ):Play()


                            game.TweenService:Create(
                                ReboundGui,
                                TweenInfo.new(0.3),
                                {
                                    ImageTransparency = 1
                                }
                            ):Play()


                            task.wait(1)

                            ReboundJs:Destroy()
                        end)
                    end
                end


                -- =====================================================
                -- CAMERA SHAKE
                -- =====================================================

                if
                    entityPart
                    and root
                    and (
                        entityPart.Position -
                        root.Position
                    ).Magnitude <= 60
                then

                    camShake:Start()

                    camShake:ShakeOnce(
                        17,
                        6,
                        0.1,
                        1
                    )
                end
            end
        end
    end)


    -- =========================================================
    -- MOVE THROUGH ROOMS
    -- =========================================================

    for i =
        latestRoom.Value,
        1,
        -1
    do

        local room =
            currentRooms:FindFirstChild(i)


        if room and room:FindFirstChild("RoomStart") then

            local roomEnd =
                room:FindFirstChild("RoomEnd")


            if roomEnd then

                local jerk =
                    game.TweenService:Create(
                        entityPart,

                        TweenInfo.new(
                            speed,
                            Enum.EasingStyle.Sine,
                            Enum.EasingDirection.Out,
                            0,
                            false,
                            0
                        ),

                        {
                            CFrame =
                                roomEnd.CFrame +
                                Vector3.new(
                                    0,
                                    0.4,
                                    0
                                )
                        }
                    )


                jerk:Play()

                jerk.Completed:Wait()
            end
        end
    end


    entityPart.Anchored = false
    entityPart.CanCollide = false

    game.Debris:AddItem(
        entity,
        5
    )
end


-- =============================================================
-- SPAWN REBOUND
-- =============================================================

local function SpawnReb()

    local maxRebounds = 3


    local rebarrival =
        G.LoadGithubAudio(
            "https://raw.githubusercontent.com/Francisco1692qzd/RevivedOldHardcore/main/Warning.mp3"
        )


    local arrival =
        Instance.new("Sound")

    arrival.SoundId =
        rebarrival or ""

    arrival.Parent =
        workspace

    arrival.Volume =
        5

    arrival:Play()

    game.Debris:AddItem(
        arrival,
        10
    )


    local cameraShaker =
        require(game.ReplicatedStorage.CameraShaker)

    local camera =
        workspace.CurrentCamera


    local camShake =
        cameraShaker.new(
            Enum.RenderPriority.Camera.Value,
            function(cf)
                camera.CFrame =
                    camera.CFrame * cf
            end
        )


    local Warn =
        Instance.new(
            "ColorCorrectionEffect",
            game.Lighting
        )


    Warn.TintColor =
        Color3.fromRGB(
            65,
            138,
            255
        )

    Warn.Saturation =
        -0.7

    Warn.Contrast =
        0.2


    game.TweenService:Create(
        Warn,
        TweenInfo.new(15),
        {
            TintColor =
                Color3.fromRGB(
                    255,
                    255,
                    255
                ),

            Saturation = 0,

            Contrast = 0
        }
    ):Play()


    game.Debris:AddItem(
        Warn,
        15
    )


    camShake:Start()

    camShake:ShakeOnce(
        10,
        3,
        0.1,
        6,
        2,
        0.5
    )


    pcall(Rebound)


    while maxRebounds > 0 do

        game.ReplicatedStorage.GameData.LatestRoom.Changed:Wait()

        task.wait(2)

        pcall(Rebound)

        maxRebounds =
            maxRebounds - 1
    end
end


task.spawn(SpawnReb)
