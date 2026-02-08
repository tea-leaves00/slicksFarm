function loadMap(path)
    local mapData = {}
    for line in love.filesystem.lines(path) do
        local row = {}
        for i=1, #line do
            local char = line:sub(i, i)
            table.insert(row, char)
        end
        table.insert(mapData, row)
    end
    return mapData
end

function loadTiles(map, cellSize)
    local tiles = {}
    
    for rowIndex, row in ipairs(map) do
        for colIndex, tileType in ipairs(row) do
            local tile = {
                x = (colIndex - 1) * cellSize,
                y = (rowIndex - 1) * cellSize,
                width = cellSize,
                height = cellSize,
                type = tileType
            }
            table.insert(tiles, tile)
        end
    end
    
    return tiles
end

function loadAtlas(spritesheet, cellSize)
    local atlas = {}
    atlas.width = spritesheet:getWidth()
    atlas.height = spritesheet:getHeight()

    for rowIndex = 0, atlas.height - cellSize, cellSize do
        for colIndex = 0, atlas.width - cellSize, cellSize do
            local texture = love.graphics.newQuad(colIndex, rowIndex, cellSize, cellSize, spritesheet)
            table.insert(atlas, texture)
        end
    end

    return atlas
end

function drawFarm(tiles, atlas, spritesheet)
    for i, tile in ipairs(tiles) do
        local atlasIndex = atlas.mapping[tile.type]
        if atlasIndex then
            local quad = atlas[atlasIndex]
            love.graphics.draw(spritesheet, quad, tile.x, tile.y)
        end
    end
end

function randomChoice(table)
    return table[love.math.random(1, #table)]
end

function love.keypressed(key)
    if key == "space" and slickRickTrigger >= 100 then
        slickRickMode = true
        scoreCounter = scoreCounter + 100
        slickRickTrigger = 0
    end
    if mainMenu and dialogue then
        if slick.charIdx >= #slickDialogue[slick.dialogueIdx] then
            if slick.dialogueIdx < #slickDialogue then
                slick.dialogueIdx = slick.dialogueIdx + 1
                slick.charIdx = 0
            else
                dialogue = false
                slick.spawn = false
                tutorial = true
            end
        else
            slick.charIdx = #slickDialogue[slick.dialogueIdx]
        end
    elseif mainMenu and tutorial then
        tutorial = false
        mainMenu = false
    elseif restartTrigger then
        love.load()
        mainMenu = false 
        tutorial = false
        dialogue = false
        restartTrigger = false
        return
    end
end

function isLoopClosed()
    if #tail < 10 then
        return false
    end
    
    local proximity = 20
    for i = 1, #tail - 10 do 
        local dist = math.sqrt((head.x - tail[i].x)^2 + (head.y - tail[i].y)^2)
        if dist < proximity then
            return true
        end
    end
    
    return false
end

function spawnAnimal(animal)
    local pos = startingPositions[love.math.random(1, #startingPositions)]
    local directions = {
        {x=0, y=1}, {x=0, y=-1}, {x=1, y=0}, {x=-1, y=0},
        {x=1, y=1}, {x=-1, y=1}, {x=1, y=-1}, {x=-1, y=-1},
        {x=1, y=1}, {x=-1, y=1}, {x=1, y=-1}, {x=-1, y=-1}
    }
    local dir = directions[love.math.random(1, #directions)]
    table.insert(onScreenAnimals, {quad = animal.image, 
                                   x = pos.x , y = pos.y, 
                                   speed=animal.speed,
                                   points=animal.points,
                                   dirX = dir.x, 
                                   dirY = dir.y})
end

function moveAnimal(dt)
    local bounds = {minX = 0, maxX = screen.width-64, minY = 0, maxY = screen.height-64}
    for i, animal in ipairs(onScreenAnimals) do
        animal.x = animal.x + animal.dirX * animal.speed * dt
        animal.y = animal.y + animal.dirY * animal.speed * dt

        if animal.x <= bounds.minX or animal.x >= bounds.maxX then
            animal.dirX = -animal.dirX
        end
        
        if animal.y <= bounds.minY or animal.y >= bounds.maxY then
            animal.dirY = -animal.dirY
        end
    end
end

function captureAnimal()
    local captured = false
    local score = 0
    local animalTypes = {}

    for i = #onScreenAnimals, 1, -1 do
        local animal = onScreenAnimals[i]
        local crossings = 0
        for j = 1, #tail - 1 do
            local x1, y1 = tail[j].x, tail[j].y
            local x2, y2 = tail[j+1].x, tail[j+1].y

            if (y1 <= animal.y and animal.y < y2) or (y2 <= animal.y and animal.y < y1) then
                local crossX = x1 + (animal.y - y1) * (x2 - x1) / (y2 - y1)
                
                if crossX > animal.x then
                    crossings = crossings + 1
                end
            end
        end
        if crossings % 2 == 1 then
            animal.deathTimer = 1
            table.insert(dyingAnimals, animal)
            table.remove(onScreenAnimals, i)
            score = score + animal.points
            animalTypes[animal.quad] = (animalTypes[animal.quad] or 0) + 1
            captured = true
        end
    end
    local animalTypeAmount = 0
    for _ in pairs(animalTypes) do 
        animalTypeAmount = animalTypeAmount + 1 
    end
    if animalTypeAmount == 1 and #dyingAnimals > 1 and score > 0 then
        score = score * 2 
    end

    return captured, score
end


function love.load()
    intro_music = love.audio.newSource("sounds/intro_song.wav", "stream")
    intro_music:setLooping(true)
    intro_music:play()
    -- fonts
    font = love.graphics.newFont("fonts/Barrio-Regular.ttf", 30)

    -- screen
    screen = {width=love.graphics.getWidth(), height=love.graphics.getHeight()}

    -- tilessssssss
    map = loadMap('map.txt')
    farmTiles = loadTiles(map, 64)
    farmSpritesheet = love.graphics.newImage('graphics/farm_atlas.png')
    farmAtlas = loadAtlas(farmSpritesheet, 64)
    farmAtlas.mapping = {
        ["0"] = 1, 
        ["1"] = 2,
        ["2"] = 3,
        ["4"] = 4,
        ["5"] = 5,
        ["6"] = 6,
        ["7"] = 7,
        ["8"] = 8,
        ["9"] = 9,
        ["A"] = 10,
        ["B"] = 11,
        ["C"] = 12,
        ["D"] = 13,
    }

    -- sprites and what not
    animalSpritesheet = love.graphics.newImage('graphics/animal_atlas.png')
    animalSpritesheet:setFilter("nearest", "nearest")
    spriteSize = 64
    animalAtlas = loadAtlas(animalSpritesheet, spriteSize)
    barn = love.graphics.newImage('graphics/barn.png')
    tractor = love.graphics.newImage('graphics/tractor.png')
    slickRick = love.graphics.newImage('graphics/slick_rick.png')

    -- the slickening
    slick = {
        spritesheet = love.graphics.newImage('graphics/slick.png'),
        frame = 1,
        animTimer = 0,
        spawn = false,
        spawnTimer = 0,
        dialogueTimer = 0,
        dialogueIdx = 1,
        charIdx = 1,
    }

    slickDialogue = {
        "Oh...hello there",
        "The name's Slick and this is my farm. But there's a small problem.",
        "The animals...they keep getting LOOSE! I ain't slept in 3 days!",
        "You look like a bonafide cowpoke. Could ya help me out?",
        "And if ya rangle together enough livestock, my buddy, Slick Rick, will come help out",
        "...",
        "Good luck, partner"
    }

    slick.atlas = loadAtlas(slick.spritesheet, 128)

    
    leeway = spriteSize * 2
    startingPositions = {
        {x = 0 + leeway, y = 0 + leeway}, -- top-left corner
        {x = screen.width/2, y = 0 + leeway}, -- top middle
        {x = screen.width - spriteSize - leeway, y = 0 + leeway}, -- top-right 
        {x = screen.width - spriteSize - leeway, y = screen.height/2}, -- right middle 
        {x = screen.width - spriteSize - leeway, y = screen.height - spriteSize - leeway}, -- bottom-right 
        {x = screen.width/2, y = screen.height - spriteSize - leeway}, -- bottom middle 
        {x = 0 + leeway, y = screen.height - spriteSize - leeway}, -- bottom-left 
        {x = 0 + leeway, y = screen.height/2} -- left middle
    }

    -- mouse 
    mouse = {x=0, y=0,
            vx=0, vy=0,
            px=0, py=0,
            down=false}
    love.mouse.setVisible(false)

    -- "corral"
    head = { x = 0, y = 0 }
    tail = {}
    delay = .9

    -- animals
    onScreenAnimals = {}
    dyingAnimals = {}
    sheep = {image=animalAtlas[1], speed=100, points=1}
    cow = {image=animalAtlas[2], speed=120, points=3}
    horse = {image=animalAtlas[3], speed=200, points=5}
    donkey = {image=animalAtlas[4], speed=300, points=10}
    pig = {image=animalAtlas[5], speed=80, points=2}
    chicken = {image=animalAtlas[6], speed=150, points=4}

    -- timers and levels and flags and what not
    mainMenu = true
    level = 1
    levelTimer = 20
    newLevelTimer = 2
    newLevel = false
    newLevelText = false
    spawnTimer = 0
    captureTimer = 0
    scoreCounter = 0
    titleGrowth = 0
    dialogue = false
    tutorial = false
    gameOver = false
    finalScoreTimer = 0
    restartTrigger = false
    slickRickTrigger = 0
    slickRickMode = false
    slickRickTimer = 0
end


function love.update(dt)

    -- so many timers
    if titleGrowth <= 3 then
        titleGrowth = titleGrowth + dt
        if titleGrowth > 3 then
            slick.spawn = true
        end
    end

    if gameOver then
        if finalScoreTimer <= 2 then
            finalScoreTimer = finalScoreTimer + dt
        else 
            restartTrigger = true
        end
    end

    -- slick animation and dialogue
    if slick.spawn then
        if slick.spawnTimer <= 2 then
            slick.spawnTimer = slick.spawnTimer + dt
        else
            dialogue = true 
            slick.dialogueTimer = slick.dialogueTimer + dt
            if slick.dialogueTimer > 0.05 then
                if slick.charIdx < #slickDialogue[slick.dialogueIdx] then
                    slick.charIdx = slick.charIdx + 1
                end
                slick.dialogueTimer = 0
            end
        end
        slick.animTimer = slick.animTimer + dt
        if slick.animTimer > 0.5 then
            slick.frame = slick.frame + 1
            if slick.frame > #slick.atlas then 
                slick.frame = 1
            end
            slick.animTimer = 0
        end
    end
    
    -- mouse movement
    mouse.x, mouse.y = love.mouse.getPosition()
    mouse.down = love.mouse.isDown(1)
    head.x = head.x + (mouse.x - head.x) * delay
    head.y = head.y + (mouse.y - head.y) * delay

    if mouse.down then
        if #tail == 0 then
            table.insert(tail, { x = head.x, y = head.y })
        else
            local lastPoint = tail[#tail]
            local dx = head.x - lastPoint.x
            local dy = head.y - lastPoint.y
            local distFromLast = math.sqrt(dx*dx + dy*dy)
            
            if distFromLast > 3 then  
                local steps = math.ceil(distFromLast / 5)
                for step = 1, steps do
                    local t = step / steps
                    table.insert(tail, {
                        x = lastPoint.x + dx * t,
                        y = lastPoint.y + dy * t
                    })
                end
            end
        end
        loopDetected = isLoopClosed()
        if loopDetected then
             captured, score = captureAnimal()
             if captured then
                scoreCounter = scoreCounter + score
                slickRickTrigger = slickRickTrigger + score
                captureTimer = 0.5
             end
        end
    else
        tail = {}
        loopDetected = false
    end

    if slickRickMode then
        if slickRickTimer <= 1 then
            slickRickTimer = slickRickTimer + dt
            onScreenAnimals = {}
        else
            slickRickMode = false
            slickRickTimer = 0
        end
    end

    -- timer for capture animation (yes more timers)
    if captureTimer > 0 then
        captureTimer = captureTimer - dt
        if captureTimer <= 0 then
            tail = {}
        end
    end

    -- spawning
    if not mainMenu then
        levelTimer = levelTimer - dt
        if levelTimer <=0 then
            newLevel = true
        end
        if newLevel then
            newLevelText = true
            level = level + 1
            if level > 10 then
                gameOver = true
            end
            levelTimer = 20
            newLevel = false
        end
        if level == 1 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <=0 then
                spawnAnimal(sheep)
                spawnTimer = 1
            end
        elseif level == 2 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then 
                local animals = {sheep, pig}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.9
            end
        elseif level == 3 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, pig}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.8
            end
        elseif level == 4 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, pig, cow}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.7
            end
        elseif level == 5 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, cow}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.6
            end
        elseif level == 6 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, cow, chicken, chicken}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.5
            end
        elseif level == 7 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, cow, cow, chicken, chicken, horse, horse}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.4
            end
        elseif level == 8 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, chicken, chicken, horse, horse, horse}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.3
            end
        elseif level == 9 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, chicken, horse, horse, donkey, donkey}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.2
            end
        elseif level == 10 then
            spawnTimer = spawnTimer - dt
            if spawnTimer <= 0 then
                local animals = {sheep, pig, cow, chicken, horse, donkey, donkey, donkey}
                spawnAnimal(randomChoice(animals))
                spawnTimer = 0.1
            end
        end
    end
    if newLevelText then
        if newLevelTimer >= 0 then
            newLevelTimer = newLevelTimer - dt
        else
            newLevelText = false
            newLevelTimer = 2
        end
    end

    moveAnimal(dt)

    -- death is inevitable
    for i = #dyingAnimals, 1, -1 do
        local animal = dyingAnimals[i]
        animal.deathTimer = animal.deathTimer - dt
        if animal.deathTimer <= 0 then
            table.remove(dyingAnimals, i)
        end
    end
end


function love.draw()
    -- env
    drawFarm(farmTiles, farmAtlas, farmSpritesheet)
    love.graphics.draw(barn)
    love.graphics.draw(tractor, screen.width - 280, screen.height - 280)

    -- text
    if mainMenu then
        love.graphics.setFont(font)
        local scale = titleGrowth
        local alpha = 3 - titleGrowth
        love.graphics.setColor(0,0,0,alpha)
        
        local text = "Slick's Farm"
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, (screen.width/2) - 30, 50, 0, scale, scale, textWidth/2, textHeight/2)
        love.graphics.setColor(1, 1, 1)

        if slick.spawn then
            local slickAlpha = slick.spawnTimer
            love.graphics.setColor(1,1,1,slickAlpha)
            love.graphics.draw(slick.spritesheet, slick.atlas[slick.frame], screen.width/2 - 128, screen.height/2 - 128, 0, 2, 2)
            love.graphics.setColor(1,1,1)
 
            local rect = {width=400, height=175}
            rect.x = screen.width/2-rect.width/2
            rect.y = 0
            if dialogue then
                love.graphics.setColor(0.96, 0.93, 0.82)
                love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 10)
                love.graphics.setColor(0, 0, 0)
                local displayText = slickDialogue[slick.dialogueIdx]:sub(1, slick.charIdx)
                love.graphics.printf(displayText, rect.x + 10, rect.y + 10, rect.width - 20, "center") 
                love.graphics.setColor(1, 1, 1) 
            end
        end
            
        if tutorial then
            local tutorialRect = {width=700, height=500}
            tutorialRect.x = screen.width/2-tutorialRect.width/2
            tutorialRect.y = screen.height/2-tutorialRect.height/2
            love.graphics.setColor(0.96, 0.93, 0.82)
            love.graphics.rectangle("fill", tutorialRect.x, tutorialRect.y, tutorialRect.width, tutorialRect.height, 20)
            love.graphics.setColor(0, 0, 0)
            local tutorialText = "Click and drag the mouse to draw a perimeter around the animals. Some animals are worth more points than others. Bonus points for capturing all the same kind of animal. Score the most points you can by level 10. Press any key to start"

            love.graphics.printf(tutorialText, tutorialRect.x+10, tutorialRect.y+10, tutorialRect.width-20, "center")
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, sheep.image, 60, 325)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 1 point", 130, 350)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, pig.image, 280, 325)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 2 points", 350, 350)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, cow.image, 510, 325)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 3 points", 580, 350)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, chicken.image, 60, 425)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 4 points", 130, 450)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, horse.image, 290, 425)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 5 points", 360, 450)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(animalSpritesheet, donkey.image, 520, 425)
            love.graphics.setColor(0,0,0)
            love.graphics.print("= 10 points", 590, 450)
            love.graphics.setColor(1, 1, 1)

        end
    elseif not mainMenu and not gameOver then
        if slickRickTrigger >= 100 then
            love.graphics.setColor(0,0,0)
            love.graphics.print("Press SPACE to activate SLICK RICK MODE!", 200, 550)
            love.graphics.setColor(1,1,1)
        end
        if slickRickMode then
            local alpha = 1 - slickRickTimer
            local scale = slickRickTimer * 4
            love.graphics.setColor(1,1,1,alpha)
            love.graphics.draw(slickRick, screen.width/2, screen.height/2, 0, scale,scale, 128, 128)
            love.graphics.setColor(1,1,1)

        end
        -- text
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("fill",0,0,175,40)
        love.graphics.setColor(0,0,0)
        love.graphics.print("Score: " .. scoreCounter)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("fill",screen.width/2-70,0,140,40)
        love.graphics.setColor(0,0,0)
        love.graphics.print("Level: "..level,screen.width/2-70,0)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("fill",screen.width-60,0,60,40)
        love.graphics.setColor(0,0,0)
        love.graphics.print(string.format("%.1f", levelTimer), screen.width-60, 0)

        if newLevelText then
            local scale = 2 - newLevelTimer
            local alpha = newLevelTimer
            love.graphics.setColor(0,0,0,alpha)
        
            local text = "Level "..level
            local textWidth = font:getWidth(text)
            local textHeight = font:getHeight()
            love.graphics.print(text, screen.width/2, screen.height/2, 0, scale, scale, textWidth/2, textHeight/2)
            love.graphics.setColor(1, 1, 1)
        end

        -- head
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", head.x, head.y, 6)
        
        -- tail
        if captureTimer > 0 then
            local pulse = math.sin(captureTimer * 10) * 0.5 + 0.5
            love.graphics.setLineWidth(2 + pulse * 5)
            for i = 1, #tail - 1 do
                love.graphics.line(tail[i].x, tail[i].y, tail[i+1].x, tail[i+1].y)
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setLineWidth(1)
            for i = 1, #tail - 1 do
                love.graphics.line(tail[i].x, tail[i].y, tail[i+1].x, tail[i+1].y)
            end
        end
        
        -- dying sprites
        for i, animal in ipairs(dyingAnimals) do
            local scale = animal.deathTimer
            local alpha = animal.deathTimer
            
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(animalSpritesheet, animal.quad, animal.x, animal.y, 0, scale, scale)
            love.graphics.setColor(1, 1, 1)
        end
        
        -- active sprites
        for i, animal in ipairs(onScreenAnimals) do
            love.graphics.draw(animalSpritesheet, animal.quad, animal.x, animal.y)
        end
    elseif not mainMenu and gameOver then
        love.graphics.setColor(0,0,0)
        local text = "Final Score: "..scoreCounter
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local scale = finalScoreTimer
        love.graphics.print(text, screen.width/2,screen.height/2,0,scale,scale,textWidth/2, textHeight/2)
        love.graphics.setColor(1,1,1)
        if restartTrigger then
            love.graphics.setColor(0,0,0)
            love.graphics.printf("Press any key to restart", 0, 350, screen.width, "center")  
            love.graphics.setColor(1,1,1)
        end
    end
end