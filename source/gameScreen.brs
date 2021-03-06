' ********************************************************************************************************
' ********************************************************************************************************
' **  Roku Prince of Persia Channel - http://github.com/lvcabral/Prince-of-Persia-Roku
' **
' **  Created: May 2016
' **  Updated: July 2016
' **
' **  Ported to Brighscript by Marcelo Lv Cabral from the Git projects:
' **  https://github.com/ultrabolido/PrinceJS - HTML5 version by Ultrabolido
' **  https://github.com/jmechner/Prince-of-Persia-Apple-II - Original Apple II version by Jordan Mechner
' **
' ********************************************************************************************************
' ********************************************************************************************************

Function PlayGame() as boolean
    'Clear screen (needed for non-OpenGL devices)
    m.mainScreen.Clear(0)
    m.mainScreen.SwapBuffers()
    m.mainScreen.Clear(0)
    'Set offsets
    m.xOff = (m.const.ROOM_WIDTH * m.scale) * m.tileSet.level.rooms[m.kid.room].x
    m.yOff = (m.const.ROOM_HEIGHT * m.scale) * m.tileSet.level.rooms[m.kid.room].y
    canvasX = Cint((m.mainWidth - m.gameWidth) / 2)
    canvasY = Cint((m.mainHeight - m.gameHeight) / 2)
    'Initialize flags and aux variables
    m.oldRoom = m.startRoom
    m.topOffset = 3 * m.scale
    m.speed = 80 '~12 fps
    m.redraw = true
    m.blink = false
    m.flash = false
    m.gameOver = false
    m.showTime = false
    m.timeShown = 0
    m.finalTime = 0
    'Load wav sounds from Mod (if one is selected)
    if m.sounds.enabled then LoadModSounds()
    'Game Loop
    m.clock.Mark()
    m.timer.Mark()
    while true
        event = m.port.GetMessage()
        if type(event) = "roUniversalControlEvent"
            id = event.GetInt()
            if id = m.code.BUTTON_BACK_PRESSED
                m.audioPlayer.stop()
                if m.kid.alive and m.kid.level.number > 2
                    saveOpt = MessageBox(m.gameScreen, 230, 100, "Save Game?")
                    if saveOpt = m.const.BUTTON_YES
                        if m.savedGame = invalid then m.savedGame = {}
                        m.savedGame.level = m.kid.level.number
                        m.savedGame.checkPoint = m.kid.checkPoint
                        m.savedGame.health = m.startHealth
                        m.savedGame.time = m.levelTime
                        m.savedGame.modId = m.settings.modId
                        SaveGame(m.savedGame)
                    end if
                else
                    saveOpt = m.const.BUTTON_NO
                end if
                if saveOpt <> m.const.BUTTON_CANCEL
                    DestroyChars()
                    m.debugMode = false
                    m.dark = false
                    return false
                end if
            else if m.gameOver
                m.gameOver = false
                m.status.Clear()
                m.checkPoint = m.kid.checkPoint
                ResetGame()
            else if id = m.code.BUTTON_INSTANT_REPLAY_PRESSED or id = m.code.BUTTON_PLAY_PRESSED
                if not m.debugMode or id = m.code.BUTTON_PLAY_PRESSED
                    m.checkPoint = m.kid.checkPoint
                    ResetGame()
                else
                    m.dark = not m.dark
                    m.redraw = true
                end if
            else if id = m.code.BUTTON_FAST_FORWARD_PRESSED
                if m.settings.rewFF = m.const.REWFF_LEVEL
                    NextLevel()
                else if m.settings.rewFF = m.const.REWFF_HEALTH
                    if m.kid.maxHealth < m.const.LIMIT_HEALTH and m.kid.alive
                        m.kid.maxHealth = m.kid.maxHealth + 1
                        m.kid.health = m.kid.maxHealth
                        PlaySound("big-life-potion", true)
                    end if
                else if m.settings.rewFF = m.const.REWFF_TIME
                    m.startTime = m.startTime + 60
                    m.status.Clear()
                    m.showTime = true
                end if
            else if id = m.code.BUTTON_REWIND_PRESSED
                if m.settings.rewFF = m.const.REWFF_LEVEL
                    PreviousLevel()
                else if m.settings.rewFF = m.const.REWFF_HEALTH
                    if m.kid.alive
                        m.kid.injured(true)
                        PlaySound("harm", true)
                    end if
                else if m.settings.rewFF = m.const.REWFF_TIME
                    if m.timeLeft > 60 then
                        m.startTime = m.startTime - 60
                        m.status.Clear()
                        m.showTime = true
                    end if
                end if
            else if id = m.code.BUTTON_SELECT_PRESSED
                if m.debugMode
                    m.debugMode = false
                    m.dark = false
                    m.status.Clear()
                    m.showTime = true
                else
                    m.saveFrameName = ""
                    m.debugMode = true
                    m.kid.haveSword = true
                    m.kid.flee = false
                    version = "v" + m.manifest.major_version + "." + m.manifest.minor_version + "." + m.manifest.build_version
                    m.status.Push({text: version + " * DEBUG MODE ON", duration: 2, alert: false})
                end if
                m.redraw = true
            else
                m.kid.cursors.update(id, m.kid.swordDrawn)
            end if
        else if event = invalid
            ticks = m.clock.TotalMilliseconds()
            if ticks > m.speed
                'Update sprites
                if not m.redraw then m.redraw = CheckMapRedraw()
                KidUpdate()
                if m.redraw or CheckVerticalNav()
                    DrawLevelRooms(m.xOff, m.yOff, m.gameWidth, m.gameHeight)
                end if
                special = CheckSpecialEvents()
                if special = m.const.SPECIAL_CONTINUE
                    GuardsUpdate()
                    CheckForOpponent(m.kid.room)
                    TROBsUpdate()
                    MOBsUpdate()
                    MaskUpdate()
                    FlashBackGround(m.kid.effect)
                    SoundUpdate()
                    if CheckGameTimer() then return true
                    'Paint Screen
                    m.compositor.AnimationTick(ticks)
                    m.compositor.DrawAll()
                    if m.flip
                        m.mainScreen.DrawObject(canvasX, canvasY, FlipVertically(m.gameCanvas))
                    end if
                    DrawStatusBar(m.gameScreen, m.gameWidth, m.gameHeight)
                    m.mainScreen.SwapBuffers()
                    m.clock.Mark()
                else if special = m.const.SPECIAL_FINISH
                    return true
                end if
            end if
        end if
    end while
End Function

Sub FlipScreen()
    g = GetGlobalAA()
    g.flip = not g.flip
    if g.flip then
        g.compositor.SetDrawTo(g.gameCanvas, g.colors.black)
        g.speed = 30
    else
        g.compositor.SetDrawTo(g.gameScreen, g.colors.black)
        g.speed = 80
    end if
End Sub

Sub KidUpdate()
    m.kid.update()
    kdRegion = m.regions.kid[m.kid.face].Lookup(m.kid.frameName).Copy()
    if m.kid.cropY < 0
        kdRegion.offset(0, - m.kid.cropY * m.scale, 0, m.kid.cropY * m.scale)
    end if
    if m.kid.faceL()
        anchorX = (m.kid.x * m.scale)
    else
        anchorX = (m.kid.x * m.scale) - kdRegion.GetWidth()
    end if
    anchorY = (m.kid.y * m.scale) - kdRegion.GetHeight() + m.topOffset
    if m.kid.sprite = invalid
        m.kid.sprite = m.compositor.NewSprite(anchorX, anchorY, kdRegion, m.kid.z)
    else
        m.kid.sprite.SetRegion(kdRegion)
        m.kid.sprite.MoveTo(anchorX, anchorY)
    end if
    DebugInfo(anchorX, anchorY)
    'Sword Sprite Update
    if m.kid.sword.visible
        if m.kid.sword.sprite <> invalid
            m.kid.sword.sprite.remove()
        end if
        swRegion = m.regions.sword[m.kid.face].Lookup(m.kid.sword.frameName)
        if swRegion <> invalid
            if m.kid.faceL()
                swX = (m.kid.x - m.kid.sword.x) * m.scale
            else
                swX = (m.kid.x + m.kid.sword.x) * m.scale - swRegion.GetWidth()
            end if
            swY = (m.kid.y + m.kid.sword.y) * m.scale - swRegion.GetHeight() + m.topOffset
            swZ = m.kid.z + m.kid.sword.z
            m.kid.sword.sprite = m.compositor.NewSprite(swX, swY, swRegion, swZ)
        end if
    else if m.kid.sword.sprite <> invalid
        m.kid.sword.sprite.remove()
    end if
    'Harm splash update
    if m.kid.splash.sprite <> invalid
        m.kid.splash.sprite.remove()
    end if
    if m.kid.splash.visible
        spRegion = m.regions.general.Lookup(m.kid.splash.frameName)
        if spRegion <> invalid
            spX = (m.kid.sprite.GetX() + kdRegion.GetWidth() / 2) - spRegion.GetWidth() / 2
            spY = (m.kid.sprite.GetY() + kdRegion.GetHeight() / 2) - spRegion.GetHeight() / 2
            m.kid.splash.sprite = m.compositor.NewSprite(spX, spY, spRegion, 25)
        end if
    end if
    'Disable Weightless state
    if m.kid.isWeightless and m.sounds.mp3.cycles = 0 then m.kid.isWeightless = false
    'Disable flip screen if kid is dead
    if not m.kid.alive and m.flip then FlipScreen()
    'Check level success
    if m.kid.success and m.sounds.mp3.cycles = 0 then NextLevel()
End Sub

Sub GuardsUpdate()
    for each guard in m.guards
        guard.update()
        gdRegion = m.regions.guards.Lookup(guard.charImage)[guard.face].Lookup(guard.frameName)
        if guard.faceL()
            anchorX = (guard.x * m.scale) - m.xOff
        else
            anchorX = (guard.x * m.scale) - gdRegion.GetWidth() - m.xOff
        end if
        anchorY = (guard.y * m.scale) - gdRegion.GetHeight() + m.topOffset - m.yOff
        if guard.opponent <> invalid or guard.charName = "shadow" then DebugGuard(anchorX, anchorY, guard)
        if guard.sprite = invalid and anchorX > 0 and anchorX <= m.gameWidth and anchorY > 0 and anchorY <= m.gameHeight
            guard.sprite = m.compositor.NewSprite(anchorX, anchorY, gdRegion, guard.z)
            guard.sprite.SetData(guard.charName)
            guard.sprite.SetDrawableFlag(guard.visible)
        else if guard.sprite <> invalid
            guard.sprite.SetRegion(gdRegion)
            guard.sprite.MoveTo(anchorX,anchorY)
            guard.sprite.SetDrawableFlag(guard.visible)
        end if
        'Sword Sprite Update
        if guard.sword.visible and guard.visible and guard.sprite <> invalid
            if guard.sword.sprite <> invalid
                guard.sword.sprite.remove()
            end if
            swRegion = m.regions.sword[guard.face].Lookup(guard.sword.frameName)
            if swRegion <> invalid
                if guard.faceL()
                    swX = (guard.x - guard.sword.x) * m.scale - m.xOff
                else
                    swX = (guard.x + guard.sword.x) * m.scale - swRegion.GetWidth() - m.xOff
                end if
                swY = (guard.y + guard.sword.y) * m.scale - swRegion.GetHeight() + m.topOffset - m.yOff
                swZ = guard.z + guard.sword.z
                guard.sword.sprite = m.compositor.NewSprite(swX, swY, swRegion, swZ)
            end if
        else if guard.sword.sprite <> invalid
            guard.sword.sprite.remove()
        end if
        'Harm splash update
        if guard.splash.sprite <> invalid then guard.splash.sprite.remove()
        if guard.splash.visible and guard.visible
            spRegion = m.regions.general.Lookup(guard.splash.frameName)
            if spRegion <> invalid
                spX = (guard.sprite.GetX() + gdRegion.GetWidth() / 2) - spRegion.GetWidth() / 2
                spY = (guard.sprite.GetY() + gdRegion.GetHeight() / 2) - spRegion.GetHeight() / 2
                guard.splash.sprite = m.compositor.NewSprite(spX, spY, spRegion, 25)
            end if
        end if
    next
End Sub

Sub DestroyChars()
    if m.kid <> invalid
        m.kid.opponent = invalid
        if m.kid.sprite <> invalid then m.kid.sprite.Remove()
        if m.kid.sword.sprite <> invalid then m.kid.sword.sprite.Remove()
        if m.kid.splash.sprite <> invalid then m.kid.splash.sprite.Remove()
        m.kid = invalid
    end if
    if m.reflex <> invalid
        m.reflex.kid.Remove()
        m.reflex.kid = invalid
        m.reflex.mask.Remove()
        m.reflex.mask = invalid
        m.reflex = invalid
    end if
    if m.guards <> invalid and m.guards.Count() > 0
        for each guard in m.guards
            if guard.sprite <> invalid then  guard.sprite.Remove()
            if guard.sword.sprite <> invalid then guard.sword.sprite.remove()
            if guard.splash.sprite <> invalid then guard.splash.sprite.remove()
        next
        m.guards.Clear()
    end if
    if m.mouse <> invalid
        if m.mouse.sprite <> invalid then m.mouse.sprite.Remove()
        m.mouse = invalid
    end if
End Sub

Function CheckGameTimer() as boolean
    finishGame = false
    if m.finalTime = 0 then m.timeLeft = m.startTime - m.timer.TotalSeconds()
    if m.kid.alive and m.timeLeft <> m.timeShown and m.timeLeft <= 60
        m.status.Push({ text: itostr(m.timeLeft) + " SECONDS LEFT", duration: 0, alert: false})
        if m.timeLeft <= 0
            PlayScene(m.gameScreen, 16, false)
            return true
        end if
        m.timeShown = m.timeLeft
    else if m.kid.alive and m.timeLeft <> m.timeShown and (m.timeLeft mod 300 = 0 or m.showTime)
        m.status.Push({ text: itostr(CInt(m.timeLeft / 60)) + " MINUTES LEFT", duration: 2, alert: false})
        m.timeShown = m.timeLeft
        m.showTime = false
    else if not m.kid.alive and not m.gameOver and m.sounds.mp3.cycles = 0
        m.gameOver = true
        m.debugMode = false
        m.dark = false
        m.status.Clear()
        m.status.Push({text: "Press Button to Continue", duration: 15, alert: false})
        m.status.Push({text: "Press Button to Continue", duration: 6, alert: true})
    else if m.gameOver and m.status.Count() = 0
        finishGame = true
    end if
    if finishGame
        m.kid.opponent = invalid
        m.kid.sprite.Remove()
        m.kid = invalid
    end if
    return finishGame
End Function

Sub TROBsUpdate()
    slicerCount = 0
    slicerState = 0
    slicerGap = 0
    for each trob in m.trobs
        if trob.tile.element = m.const.TILE_EXIT_RIGHT and m.kid.room = m.kid.level.prince.room and m.kid.room = trob.tile.room
            'Close Door on the start of every level
            if not trob.tile.dropped and trob.sprite.childBack <> invalid
                trob.tile.state = trob.tile.STATE_OPEN
                trob.tile.child.back.height = (8 + trob.tile.type)
                rgn = trob.sprite.childBack.GetRegion()
                rgn.offset(0, 50 * m.scale, 0, -50 * m.scale)
                trob.tile.drop()
                PlaySound("exit-door-close")
            end if
        else if trob.tile.element = m.const.TILE_SLICER and trob.tile.roomY = m.kid.blockY and trob.sprite.visible
            'Start slicer(s) when kid is on the same Y
            roomT = trob.tile.room
            roomK = m.kid.room
            roomL = m.tileSet.level.rooms[m.kid.room].links.left
            roomR = m.tileSet.level.rooms[m.kid.room].links.right
            if roomT = roomL or roomT = roomK or roomT = roomR
                if not trob.tile.active
                    trob.tile.start()
                    trob.tile.stage = trob.tile.stage - slicerGap
                    slicerGap = slicerGap + 5
                    if slicerGap = 15 then slicerGap = 0
                end if
            end if
        end if
        'Update TROB state
        trob.tile.update()
        'Paint TROB if needed and is on screen
        if trob.tile.redraw and trob.sprite.visible
            if trob.tile.element = m.const.TILE_GATE
                trob.sprite.childFront.setDrawableFlag(trob.tile.state = trob.tile.STATE_CLOSED)
                if trob.tile.state = trob.tile.STATE_RAISING
                    rgn = trob.sprite.childBack.GetRegion()
                    rgn.offset(0, 1 * m.scale, 0, -1 * m.scale)
                else if trob.tile.state = trob.tile.STATE_DROPPING
                    if trob.tile.stage = 0
                        rgn = trob.sprite.childBack.GetRegion()
                        rgn.offset(0, -1 * m.scale, 0, 1 * m.scale)
                    end if
                else if trob.tile.state = trob.tile.STATE_FAST_DROPPING
                    rgn = trob.sprite.childBack.GetRegion()
                    rgn.offset(0, -10 * m.scale, 0, 10 * m.scale)
                else if trob.tile.state = trob.tile.STATE_CLOSED
                    trob.sprite.childBack.SetRegion(m.regions.tiles.Lookup(trob.tile.child.back.frameName).Copy())
                end if
            else if trob.tile.element = m.const.TILE_RAISE_BUTTON or trob.tile.element = m.const.TILE_DROP_BUTTON
                if trob.tile.front <> invalid and trob.sprite.front <> invalid
                    trob.sprite.front.setRegion(m.regions.tiles.Lookup(trob.tile.front))
                    trob.sprite.front.setDrawableFlag(true)
                else if trob.sprite.front <> invalid
                    trob.sprite.front.setDrawableFlag(false)
                end if
                trob.sprite.back.setRegion(m.regions.tiles.Lookup(trob.tile.back))
            else if trob.tile.element = m.const.TILE_POTION
                if trob.tile.front = trob.tile.key + "_" + itostr(m.const.TILE_FLOOR) + "_fg" or trob.tile.front = trob.tile.key + "_" + itostr(m.const.TILE_DEBRIS) + "_fg"
                    trob.sprite.front.setRegion(m.regions.tiles.Lookup(trob.tile.front))
                    trob.sprite.back.setRegion(m.regions.tiles.Lookup(trob.tile.back))
                    if trob.sprite.childBack <> invalid
                        trob.tile.child.back.frames = invalid
                        trob.sprite.childBack.Remove()
                    end if
                end if
            else if trob.tile.element = m.const.TILE_SWORD or trob.tile.element = m.const.TILE_TORCH
                trob.sprite.back.setRegion(m.regions.tiles.Lookup(trob.tile.back))
            else if trob.tile.element = m.const.TILE_SPIKES
                if trob.tile.modifier = 0
                    trob.sprite.childBack.setRegion(m.regions.tiles.Lookup(trob.tile.child.back.frameName))
                    trob.sprite.childFront.setRegion(m.regions.tiles.Lookup(trob.tile.child.front.frameName))
                end if
            else if trob.tile.element = m.const.TILE_SLICER
                trob.sprite.childBack.setRegion(m.regions.tiles.Lookup(trob.tile.child.back.frameName))
                trob.sprite.childFront.setRegion(m.regions.tiles.Lookup(trob.tile.child.front.frameName))
                if trob.tile.blood.visible
                    bloodX = 12
                    if m.settings.spriteMode = m.const.SPRITES_MAC
                        bloodY = [44,65,55,31,31]
                        x = (trob.tile.x * m.scale) + (bloodX * m.scale / 2)
                        y = (trob.tile.y * m.scale) + (bloodY[trob.tile.stage-1] * m.scale / 2)
                    else
                        bloodY = [53,40,44,64,60]
                        x = (trob.tile.x + bloodX) * m.scale
                        y = (trob.tile.y + bloodY[trob.tile.stage-1]) * m.scale
                    end if
                    if trob.sprite.blood = invalid
                        rgBlood = m.regions.general.Lookup(trob.tile.blood.frameName)
                        trob.sprite.blood = m.compositor.NewSprite(x - m.xOff, y - m.yOff, rgBlood, 35)
                        m.map.Push(trob.sprite.blood)
                    else
                        trob.sprite.blood.setRegion(m.regions.general.Lookup(trob.tile.blood.frameName))
                        trob.sprite.blood.MoveTo(x - m.xOff, y - m.yOff)
                    end if
                end if
            else if trob.tile.element = m.const.TILE_EXIT_RIGHT
                if trob.tile.state = trob.tile.STATE_RAISING
                    rgn = trob.sprite.childBack.GetRegion()
                    if m.settings.spriteMode = m.const.SPRITES_MAC and trob.tile.type = m.const.TYPE_DUNGEON
                        if trob.tile.child.back.y < 15
                            trob.tile.child.back.y = trob.tile.child.back.y + 1
                            trob.sprite.childBack.MoveTo(trob.sprite.childBack.GetX(),  trob.sprite.childBack.GetY() + 1 * m.scale)
                        end if
                    end if
                    rgn.offset(0, 1 * m.scale, 0, -1 * m.scale)
                else if trob.tile.state = trob.tile.STATE_DROPPING
                    rgn = trob.sprite.childBack.GetRegion()
                    rgn.offset(0, -10 * m.scale, 0, 10 * m.scale)
                else if trob.tile.state = trob.tile.STATE_OPEN
                    if m.settings.spriteMode = m.const.SPRITES_MAC and trob.tile.type = m.const.TYPE_DUNGEON
                        trob.tile.child.back.y = 15
                    end if
                end if
                trob.sprite.childBack.setDrawableFlag(trob.tile.child.back.visible)
                trob.sprite.childFront.setDrawableFlag(trob.tile.child.front.visible)
            end if
            trob.tile.redraw = false
        end if
    next
End Sub

Sub MOBsUpdate()
    for each mob in m.mobs
        if mob.tile <> invalid
            'Update MOB state
            mob.tile.update()
            'Paint MOB if needed and is on screen
            if mob.tile.redraw
                if mob.tile.element = m.const.TILE_LOOSE_BOARD
                    if mob.sprite.back <> invalid and mob.sprite.visible
                        mob.sprite.back.setRegion(m.regions.tiles.Lookup(mob.tile.back))
                    else
                        if mob.sprite.back <> invalid then mob.sprite.back.Remove()
                        if mob.tile.backSprite <> invalid then mob.tile.backSprite.Remove()
                    end if
                    if mob.tile.state = mob.tile.STATE_SHAKING
                        if mob.sprite.visible
                            if mob.sprite.front <> invalid then mob.sprite.front.setDrawableFlag(false)
                        else
                            if mob.sprite.front <> invalid then mob.sprite.front.Remove()
                        end if
                    else if mob.tile.state = mob.tile.STATE_INACTIVE
                        if mob.sprite.visible then
                            if mob.sprite.front <> invalid then mob.sprite.front.setDrawableFlag(true)
                        else
                            if mob.sprite.front <> invalid then mob.sprite.front.Remove()
                        end if
                    else if mob.tile.state = mob.tile.STATE_FALLING
                        if mob.sprite.front <> invalid then mob.sprite.front.Remove()
                        if mob.sprite.back <> invalid and mob.sprite.visible
                            mob.sprite.back.MoveTo(mob.tile.x * m.scale - m.xOff, mob.tile.y * m.scale - m.yOff)
                        end if
                        if mob.floor = invalid or mob.tile.stage = 0
                            if mob.tile.type = m.const.TYPE_PALACE
                                space = mob.tile.key + "_0_1"
                            else
                                space = mob.tile.key + "_0_0"
                            end if
                            mob.floor = m.tileSet.level.floorStartFall(mob.tile)
                            if mob.sprite.back <> invalid then
                                m.map.Push(m.compositor.NewSprite(mob.sprite.back.GetX(), mob.sprite.back.GetY(), m.regions.tiles.Lookup(space), 10))
                                mob.floor.fromAbove = IsFromAbove(mob.sprite.back, m.kid.sprite)
                            end if
                        end if
                        if mob.floor <> invalid
                            if mob.floor.fromAbove and m.kid.blockX = mob.tile.roomX and CheckPlateHitFromAbove(mob.sprite.back, m.kid.sprite)
                                print "injured with plate:";m.kid.action();m.kid.blockX
                                m.kid.action("medland")
                                mob.floor.fromAbove = false
                            end if
                        end if
                    else if mob.tile.state = mob.tile.STATE_CRASHED
                        if mob.sprite.back <> invalid then mob.sprite.back.Remove()
                        if mob.tile.backSprite <> invalid then mob.tile.backSprite.Remove()
                        if mob.floor <> invalid
                            debris = m.tileSet.level.floorStopFall(mob.floor)
                            if debris <> invalid and debris.backSprite <> invalid and debris.frontSprite <> invalid
                                debris.backSprite.SetRegion(m.regions.tiles.Lookup(debris.back))
                                debris.frontSprite.SetRegion(m.regions.tiles.Lookup(debris.front))
                            end if
                            mob.tile.element = m.const.TILE_SPACE
                            mob.tile = invalid
                            mob.floor = invalid
                        end if
                    end if
                end if
                if mob.tile <> invalid then mob.tile.redraw = false
            end if
        end if
    next
End Sub

Sub MaskUpdate()
    'Mask tile
    if m.kid.level.masked.Count() > 0
        for i = 0 to m.kid.level.masked.Count() - 1
            tt = m.kid.level.masked[i]
            if  tt <> invalid and tt.frontSprite <> invalid
                if tt.back <> invalid
                    ts = tt.frontSprite
                    if tt.isMasked
                        rgn = m.regions.tiles.Lookup(tt.back).Copy()
                        rgn.offset(0, 0, -33 * m.scale, 0)
                        ts.setRegion(rgn)
                    else if tt.element = m.const.TILE_RAISE_BUTTON or tt.element = m.const.TILE_DROP_BUTTON
                        ts.setDrawableFlag(not tt.active)
                    else if tt.front <> invalid
                        rgn = m.regions.tiles.Lookup(tt.front)
                        ts.setRegion(rgn)
                    end if
                end if
                tt.redraw = false
            end if
        next
        for each tt in m.kid.level.masked
            if  tt <> invalid and tt.isMasked then return
        next
        m.kid.level.masked.Clear()
    end if
End Sub

Sub DrawLevelRooms(xOffset = 0 as integer, yOffset = 0 as integer, maxWidth=1280 as integer, maxHeight=720 as integer)
    'Clear map if exists
    DestroyMap()
    if m.dark then return
    'Draw level rooms
    m.map = [m.compositor.NewSprite(0, 0, CreateObject("roRegion",GetPaintedBitmap(255,maxWidth,maxHeight,true),0,0,maxWidth,maxHeight), 1)]
    m.trobs = []
    for ry = m.tileSet.level.height - 1 to 0 step -1
		for rx = 0 to m.tileSet.level.width - 1
			r = m.tileSet.level.layout[ry][rx]
			if r <> -1 and m.tileSet.level.rooms[r] <> invalid
                for ty = 2 to 0 step -1
                    if not m.tileSet.level.rooms[r].links.hideLeft and m.tileSet.level.rooms[r].left.count() > 0
                        z = m.tileSet.level.rooms[r].links.leftZ
                        DrawTile(m.tileSet.level.rooms[r].left[ty], xOffset, yOffset, maxWidth, maxHeight, z)
                    end if
                    if m.tileSet.level.rooms[r].right.count() > 0
                        DrawTile(m.tileSet.level.rooms[r].right[ty], xOffset, yOffset, maxWidth, maxHeight)
                    end if
                    for tx = 0 to 9
                        tile = m.tileSet.level.rooms[r].tiles[ty * 10 + tx]
                        DrawTile(tile, xOffset, yOffset, maxWidth, maxHeight)
                        if not m.tileSet.level.rooms[r].links.hideUp and m.tileSet.level.rooms[r].up.count() > 0
                            DrawTile(m.tileSet.level.rooms[r].up[tx], xOffset, yOffset, maxWidth, maxHeight, 15)
                        end if
                    next
                next
            end if
        next
    next
    print "map repainted"; m.mobs.count()
    m.redraw = false
End Sub

Sub DrawTile(tile as object, xOffset as integer, yOffset as integer, maxWidth as integer, maxHeight as integer, backZ=10 as integer, frontZ = 30 as integer)
    if tile = invalid or tile.x = invalid then return
    if tile.isTrob() or tile.isMob()
        obj = {tile: tile, sprite: {visible: false} }
        obj.tile.audio = false
    end if
    x = (tile.x * m.scale) - xOffset
    y = (tile.y * m.scale) - yOffset
    yd = 0
    if x >= -m.const.TILE_WIDTH * m.scale and x <= maxWidth and y >= -m.const.TILE_HEIGHT * m.scale and y<=maxHeight 'only what can be shown
        if tile.isTrob() or tile.isMob()
            obj.sprite.visible = true
            if x < maxWidth-tile.width then obj.tile.audio = true
        end if
        if tile.back <> invalid
            tileRegion = m.regions.tiles.Lookup(tile.back)
            if tileRegion = invalid
                tileRegion = m.regions.tiles.Lookup(tile.key + "_0")
            end if
            if tileRegion.GetHeight() > m.const.TILE_HEIGHT * m.scale
                yd = tileRegion.GetHeight() - m.const.TILE_HEIGHT * m.scale
            end if
            sprite = m.compositor.NewSprite(x, y - yd, tileRegion, backZ)
            if tile.isWalkable() or tile.element = m.const.TILE_SPACE
                if tile.backSprite <> invalid  then tile.backSprite.Remove()
                tile.backSprite = sprite
            end if
            if tile.isTrob() or tile.isMob() then obj.sprite.back = sprite
            if tile.isTrob() or not tile.isMob() then m.map.Push(sprite)
        end if
        if tile.front <> invalid
            if tile.type = m.const.TYPE_PALACE and tile.element = m.const.TILE_WALL
                wc = m.tileSet.wallColor
                bmd = CreateObject("roBitmap", {width:m.const.TILE_WIDTH, height:m.const.TILE_HEIGHT, alphaenable:true})
                bmd.drawrect(0,16,32,20, wc[rnd(wc.count())-1])
                bmd.drawrect(0,36,16,21, wc[rnd(wc.count())-1])
                bmd.drawrect(16,36,16,21, wc[rnd(wc.count())-1])
                bmd.drawrect(0,57,8,19, wc[rnd(wc.count())-1])
                bmd.drawrect(8,57,24,19, wc[rnd(wc.count())-1])
                bmd.drawrect(0,76,32,3, wc[rnd(wc.count())-1])
				bms = ScaleBitmap(bmd, m.scale)
                if m.settings.spriteMode = m.const.SPRITES_MAC
                    tb = (m.const.TILE_HEIGHT - m.const.BLOCK_HEIGHT - 3) * m.scale
                    bms.DrawObject((m.const.TILE_WIDTH - 8) * m.scale, tb + 3 * m.scale, m.regions.tiles.Lookup(WallMarks(0)))
                    bms.DrawObject(0, tb + 16 * m.scale, m.regions.tiles.Lookup(WallMarks(1)))
                    bms.DrawObject(0, tb + 38 * m.scale, m.regions.tiles.Lookup(WallMarks(2)))
                    bms.DrawObject(0, tb + 57 * m.scale, m.regions.tiles.Lookup(WallMarks(3)))
                    bms.DrawObject(0, tb + 63 * m.scale, m.regions.tiles.Lookup(WallMarks(4)))
                end if
                frsp = m.compositor.NewSprite(x, y, CreateObject("roRegion",bms,0,0,bms.GetWidth(),bms.GetHeight()), frontZ)
            else
                tr = m.regions.tiles.Lookup(tile.front)
                if tr = invalid and tile.element = m.const.TILE_WALL
                    tr = m.regions.tiles.Lookup(Left(tile.front,4) + "15")
                else if tr = invalid
                    tr = m.regions.tiles.Lookup(tile.key + "_0")
                    stop
                end if
                frsp = m.compositor.NewSprite(x, y, tr , frontZ)
                if frsp = invalid then stop
            end if
            m.map.Push(frsp)
            if tile.isWalkable() or tile.element = m.const.TILE_SPACE
                'link the tile to allow masking
                if tile.frontSprite <> invalid then tile.frontSprite.Remove()
                tile.frontSprite = frsp
            end if
            if tile.isTrob() or tile.isMob()
                obj.sprite.front = frsp
            end if
            if tile.element = m.const.TILE_SLICER
                if m.debugMode
                    print "debug box "; x;y;tile.getBounds().width;tile.getBounds().height
                    bw = tile.getBounds().width * m.scale
                    bh = tile.getBounds().height * m.scale
                    bmt = CreateObject("roBitmap", {width:bw, height:bh, alphaenable:true})
                    bmt.drawrect(0,0,bw, bh, m.colors.red)
                    slr = CreateObject("roRegion",bmt,0,0,bmt.GetWidth(),bmt.GetHeight())
                    m.map.Push(m.compositor.NewSprite(x + (15*m.scale), y + (10*m.scale), slr, 35))
                end if
            end if
        end if
        'Child frames
        chbk = tile.child.back
        chfr = tile.child.front
        if chbk.frameName <> invalid
            rgn = m.regions.tiles.Lookup(chbk.frameName).Copy()
            if tile.cropY < 0
                rgn.offset(0, - tile.cropY * m.scale, 0, tile.cropY * m.scale)
            end if
            spbk = m.compositor.NewSprite(x + chbk.x * m.scale, (y - yd) + chbk.y * m.scale, rgn, backZ)
            spbk.setDrawableFlag(chbk.visible)
            if tile.isTrob() then obj.sprite.childBack = spbk
            m.map.Push(spbk)
        else if tile.child.back.frames <> invalid
            animation = []
            for each frameName in tile.child.back.frames
                animation.Push(m.regions.general.Lookup(frameName))
            next
            spbk = m.compositor.NewAnimatedSprite(x + chbk.x * m.scale, (y - yd) + chbk.y * m.scale, animation, backZ)
            if tile.isTrob() then obj.sprite.childBack = spbk
            m.map.Push(spbk)
        end if
        if chfr.frameName <> invalid
            chrg = m.regions.tiles.Lookup(chfr.frameName)
            if chrg = invalid and Left(chfr.frameName, 2) = "W_"
                chrg = m.regions.tiles.Lookup("W_15")
            end if
            spfr = m.compositor.NewSprite(x + chfr.x * m.scale, (y - yd) + chfr.y * m.scale, chrg , frontZ)
            spfr.setDrawableFlag(chfr.visible)
            if tile.isTrob() then obj.sprite.childFront = spfr
            m.map.Push(spfr)
        end if
    end if
    if tile.isTrob()
        m.trobs.Push(obj)
    else if tile.isMob()
        m.mobs.Push(obj)
    end if
    tile.redraw = false
End Sub

Sub DestroyMap()
    if m.mobs <> invalid
        new = []
        for each mob in m.mobs
            if mob.tile <> invalid and mob.tile.element = m.const.TILE_LOOSE_BOARD
                if mob.tile.fall
                    new.Push(mob)
                else if mob.sprite.back <> invalid
                    mob.sprite.back.remove()
                end if
            end if
        next
        m.mobs.clear()
        m.mobs = new
    else
        m.mobs = []
    end if
    if m.map <> invalid
        for each sprite in m.map
            if sprite <> invalid then sprite.remove()
        next
    end if
End Sub

Sub FlashBackGround(effect as integer)
    if effect <> m.colors.black
        m.flash = not m.flash
        if m.flash
            m.map[0].SetRegion(CreateObject("roRegion",GetPaintedBitmap(effect,m.gameWidth, m.gameHeight,true),0,0,m.gameWidth, m.gameHeight))
        else
            m.map[0].SetRegion(CreateObject("roRegion",GetPaintedBitmap(m.colors.black,m.gameWidth, m.gameHeight,true),0,0,m.gameWidth, m.gameHeight))
        end if
    else if m.flash
        m.map[0].SetRegion(CreateObject("roRegion",GetPaintedBitmap(m.colors.black,m.gameWidth, m.gameHeight,true),0,0,m.gameWidth, m.gameHeight))
        m.flash = false
    end if
End Sub

Function CheckMapRedraw() as boolean
    redraw = false
    if m.cameras = 1 and m.kid.sprite <> invalid
        kidWidth = m.kid.sprite.GetRegion().GetWidth() / m.scale
        midWidth = cint(kidWidth / 2)
        if m.kid.room <> m.oldRoom and m.kid.room >= 0
            if m.kid.x + midWidth + 6 < 0
                m.kid.baseX = m.kid.baseX + m.const.ROOM_WIDTH
                redraw = true
            end if
            if redraw
                m.xOff = (m.const.ROOM_WIDTH * m.scale) * m.tileSet.level.rooms[m.kid.room].x
                m.oldRoom = m.kid.room
                print "changed camera focus left - new offsets:"; m.xOff; m.yOff
            end if
        else if m.kid.blockX = 9 and m.tileSet.level.rooms[m.oldRoom].links.right > 0
            if m.kid.swordDrawn then gap = midWidth else gap = 0
            if m.kid.x + gap > m.const.ROOM_WIDTH
                m.kid.baseX = m.kid.baseX - m.const.ROOM_WIDTH
                redraw = true
            end if
            if redraw
                nextRoom = m.tileSet.level.rooms[m.oldRoom].links.right
                m.xOff = (m.const.ROOM_WIDTH * m.scale) * m.tileSet.level.rooms[nextRoom].x
                m.oldRoom = nextRoom
                print "changed camera focus right - new offsets:"; m.xOff; m.yOff
            end if
        end if
    else if  m.kid.sprite <> invalid
        factorX = int(m.gameWidth / 320)
        factorY = int(m.gameHeight / 200)
        kidWidth = m.kid.sprite.GetRegion().GetWidth()
        midWidth = cint(kidWidth/2)
        if m.kid.x > m.gameWidth
            nextRoom = m.tileSet.level.rooms[m.kid.room].links.right
            if nextRoom > 0 and abs(m.tileSet.level.rooms[nextRoom].x - m.tileSet.level.rooms[m.startRoom].x) mod factorX = 0
                m.kid.baseX = m.kid.baseX - m.gameWidth
                m.xOff = m.const.ROOM_WIDTH * m.tileSet.level.rooms[nextRoom].x
                redraw = true
            end if
        else if m.kid.x + midWidth + 6 < 0
            if abs(m.tileSet.level.rooms[m.kid.room].x - m.tileSet.level.rooms[m.startRoom].x) mod factorX <> 0
                m.kid.baseX = m.kid.baseX + m.gameWidth
                m.xOff = m.const.ROOM_WIDTH * (m.tileSet.level.rooms[m.kid.room].x - (factorX - 1))
                redraw = true
            end if
        else if m.kid.y > m.gameHeight
            if abs(m.tileSet.level.rooms[m.kid.room].y - m.tileSet.level.rooms[m.startRoom].y) mod factorY = 0
                m.kid.baseY = m.kid.baseY - (m.const.ROOM_HEIGHT*factorY)
                m.yOff = m.const.ROOM_HEIGHT * m.tileSet.level.rooms[m.kid.room].y
                redraw = true
            end if
        else if m.kid.y < 0
            if abs(m.tileSet.level.rooms[m.kid.room].y - m.tileSet.level.rooms[m.startRoom].y) mod factorY <> 0
                m.kid.baseY = m.kid.baseY + (m.const.ROOM_HEIGHT*factorY)
                m.yOff = m.const.ROOM_HEIGHT * (m.tileSet.level.rooms[m.kid.room].y - (factorY - 1))
                redraw = true
            end if
        end if
    end if
    return redraw
End Function

Function CheckVerticalNav() as boolean
    if m.cameras = 1
        if m.kid.room <> m.oldRoom and m.kid.room >= 0
            if m.kid.room = m.tileSet.level.rooms[m.oldRoom].links.up or m.kid.room = m.tileSet.level.rooms[m.oldRoom].links.down
                m.yOff = (m.const.ROOM_HEIGHT * m.scale) * m.tileSet.level.rooms[m.kid.room].y
                m.oldRoom = m.kid.room
                return true
            end if
        end if
    end if
    return false
End Function

Function IsFromAbove(st as object, sk as object) as boolean
    return (st.GetY() + st.GetRegion().GetHeight()) < sk.GetY()
End Function

Function CheckPlateHitFromAbove(st as object, sk as object) as boolean
    stW = st.GetRegion().GetWidth()
    stH = st.GetRegion().GetHeight()
    skW = sk.GetRegion().GetWidth()
    skH = sk.GetRegion().GetHeight()
    res = false
    if (st.GetX() + stW) > sk.GetX()
        if st.GetX() < (sk.GetX() + skW)
            if (st.GetY() + stH) >= sk.GetY()
                if (st.GetY() + stH) - skH < sk.GetY()
                    'print "hit: "; st.GetX();"<";(sk.GetX() + skW); " and ";  (st.GetX() + stW);">";sk.GetX()
                    res = true
                end if
            end if
        end if
    end if
    return  res
End Function

Sub CheckForOpponent(room as integer)
    if m.settings.fight = m.const.FIGHT_FROZEN then return
    for each guard in m.guards
        if guard.room = room and guard.alive and guard.opponent = invalid and guard.active
            m.kid.opponent = guard
            guard.opponent = m.kid
            if not m.kid.haveSword then m.kid.flee = true
        else if m.kid.opponent = invalid and guard.opponent <> invalid
            guard.opponent = invalid
        end if
    next
End Sub
