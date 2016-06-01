' ********************************************************************************************************
' ********************************************************************************************************
' **  Roku Prince of Persia Channel - http://github.com/lvcabral/Prince-of-Persia-Roku
' **
' **  Created: February 2016
' **  Updated: May 2016
' **
' **  Ported to Brighscript by Marcelo Lv Cabral from the Git projects:
' **  https://github.com/ultrabolido/PrinceJS - HTML5 version by Ultrabolido
' **  https://github.com/jmechner/Prince-of-Persia-Apple-II - Original Apple II version by Jordan Mechner
' **
' ********************************************************************************************************
' ********************************************************************************************************

Sub DrawStatusBar(screen as object, width as integer, height as integer)
    screen.DrawRect(0, height-(8* m.scale),width, (8* m.scale), m.colors.black)
    lifeFull = m.general.lookup("kid-live")
    lifeEmpty = m.general.lookup("kid-emptylive")
    if m.settings.spriteMode = m.const.SPRITES_DOS
        lifePos = 6 * m.scale
    else
        lifePos = 8 * m.scale
    end if
    if m.kid.health = 1
        if m.blink
            screen.drawobject(0, height - lifePos, lifeFull)
        else
            screen.drawobject(0, height - lifePos, lifeEmpty)
        end if
        m.blink = not m.blink
    else if m.kid.health > 1
        for h = 0 to m.kid.health-1
            screen.drawobject(lifeFull.GetWidth()*h+h, height - lifePos, lifeFull)
        next
    end if
    if m.kid.health < m.kid.maxHealth
        for h = m.kid.health to m.kid.maxHealth-1
            screen.drawobject(lifeFull.GetWidth()*h+h, height - lifePos, lifeEmpty)
        next
    end if
    enemy = m.kid.opponent
    if enemy <> invalid and enemy.health > 0 and enemy.sprite <> invalid and enemy.charName <> "skeleton"
        if enemy.swordDrawn or (enemy.sprite.GetX() > 0 and enemy.sprite.GetX() < m.gameScreen.GetWidth())
            for h = 1 to enemy.health
                guardLife = m.general.lookup(enemy.charImage + "-live")
                screen.drawobject(width - guardLife.GetWidth() * h, height - lifePos, guardLife)
            next
        end if
    end if
    if m.status.Count() > 0
        text = m.status[0].text
        if m.status[0].duration = 0
            if m.status.count() > 1 then m.status.Delete(0)
        else if m.status[0].mark = invalid
        	m.status[0].mark = m.timer.TotalMilliseconds()
            m.status[0].count = 0
        else
            timeGap = m.timer.TotalMilliseconds() - m.status[0].mark
            if timeGap >= m.status[0].duration * 1000
                m.status.Delete(0)
            else if m.status[0].alert
                if timeGap > m.status[0].count + 500
                    m.status[0].count = m.status[0].count + 500
                    if m.status[0].count mod 1000 = 0 then PlaySound("status-alert")
                end if
                if m.status[0].count mod 1000 <> 0 then text = ""
            end if
        end if
        if text <> ""
            x = int(width / 2) - (Len(text) * (7 * m.scale)) / 2
            y = height - (8 * m.scale)
            m.bitmapFont[m.scale].write(screen, text, x, y)
        end if
    end if
    DrawBorder(m.mainScreen, m.gameWidth, m.gameHeight, m.colors.gray, 2)
End Sub

Sub DrawBorder(screen as object, width as integer, height as integer, color as integer, offset as integer)
    leftX = Cint((screen.GetWidth()-width)/2) - offset
    rightX = leftX + width + offset * 2
    topY = Cint((screen.GetHeight()-height)/2) - offset
    bottomY = topY + height + offset * 2
    screen.DrawLine(leftX, topY, rightX, topY, color)
    screen.DrawLine(rightX, topY, rightX, bottomY, color)
    screen.DrawLine(rightX, bottomY, leftX, bottomY, color)
    screen.DrawLine(leftX, bottomY, leftX, topY, color)
End Sub

Sub DebugInfo(x as integer, y as integer)
    if (x <> m.saveX or y <> m.saveY or m.kid.frameName <> m.saveFrameName)
        strDebug = str(x)+","+str(y)+" "+m.kid.action()+" "+m.kid.frameName+" R:"+itostr(m.kid.room)+" T:"+ itostr(m.kid.blockX) + "," + itostr(m.kid.blockY)
        print strDebug
        if m.debugMode
            m.status.Push({text:strDebug, duration: 0, alert: false})
        end if
        m.saveX = x
        m.saveY = y
        m.saveFrameName = m.kid.frameName
    end if
End Sub

Sub DebugGuard(x as integer, y as integer, guard as object)
    if (x <> m.guardX or y <> m.guardY or guard.frameName <> m.guardFrameName)
        strDebug = "guard: "+str(x)+","+str(y)+" "+guard.action()+" "+guard.frameName+" R:"+itostr(guard.room)+" T:"+ itostr(guard.blockX) + "," + itostr(guard.blockY)
        'print strDebug
        m.guardX = x
        m.guardY = y
        m.guardFrameName = guard.frameName
    end if
End Sub

Function LoadBitmapFont(scale = 1.0 as float) As Dynamic
    this = {scale: scale}
    rsp = ReadAsciiFile("pkg:/assets/fonts/prince.fnt")
    xml=CreateObject("roXMLElement")
    if not xml.Parse(rsp) then
         print "Can't parse feed"
        return invalid
    else if xml.font = invalid then
        print "Missing font tag"
        return invalid
    endif
    xmlChars = xml.getnamedelements("chars").getchildelements()
    bitmap=CreateObject("robitmap", "pkg:/assets/fonts/prince_0.png")
    this.chars = {}
    for each char in xmlChars
        name = "chr" + char@id
        this.chars.AddReplace(name, ScaleBitmap(CreateObject("roRegion",bitmap,val(char@x),val(char@y),val(char@width),val(char@height)),scale))
    next
    this.write = write_text
    return this
End Function

Function write_text(screen as object, text as string, x as integer, y as integer) as object
	xOff = 2 * m.scale
	yOff = 8 * m.scale
    for c = 0 to len(text) - 1
        letter = m.chars.lookup("chr" + itostr(asc(text.mid(c,1))))
        yl = y + (yOff - letter.GetHeight())
        screen.drawobject(x, yl , letter)
        x = x + letter.GetWidth() + xOff
    next
End Function
