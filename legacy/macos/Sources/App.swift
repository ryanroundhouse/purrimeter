import AppKit
import AVFoundation

let ink = NSColor(calibratedRed:0.075,green:0.10,blue:0.14,alpha:1)
let panelColor = NSColor(calibratedRed:0.12,green:0.15,blue:0.19,alpha:1)
let cream = NSColor(calibratedRed:0.95,green:0.92,blue:0.82,alpha:1)
let muted = NSColor(calibratedRed:0.54,green:0.63,blue:0.64,alpha:1)
let gold = NSColor(calibratedRed:1,green:0.76,blue:0.36,alpha:1)
let mint = NSColor(calibratedRed:0.48,green:0.85,blue:0.65,alpha:1)
func accent(_ cat: Cat) -> NSColor { switch cat { case .bolt: return gold; case .cannon: return NSColor(calibratedRed:0.96,green:0.48,blue:0.40,alpha:1); case .frost: return NSColor(calibratedRed:0.44,green:0.77,blue:1,alpha:1) } }

final class Audio {
    var music: AVAudioPlayer?
    var effects: [String:[AVAudioPlayer]] = [:]
    var last: [String:Double] = [:]
    var muted = UserDefaults.standard.bool(forKey:"muted")
    init(silent: Bool = false) {
        if silent { muted=true; return }
        let base=Bundle.main.resourceURL!
        music=try? AVAudioPlayer(contentsOf:base.appendingPathComponent("garden.wav")); music?.numberOfLoops = -1; music?.volume=0.28
        for name in ["bolt","cannon","frost","coin","build","upgrade","wave","clear","escape","break","win","lose"] {
            effects[name]=(0..<3).compactMap { _ in try? AVAudioPlayer(contentsOf:base.appendingPathComponent("\(name).wav")) }
            effects[name]?.forEach { $0.volume=0.24; $0.prepareToPlay() }
        }
        if !muted { music?.play() }
    }
    func play(_ name: String) {
        guard !muted else { return }; let now=ProcessInfo.processInfo.systemUptime
        guard now-last[name,default:0] > 0.075 else { return }; last[name]=now
        if let p=effects[name]?.first(where:{!$0.isPlaying}) { p.currentTime=0; p.play() }
    }
    func toggle() { muted.toggle(); UserDefaults.standard.set(muted,forKey:"muted"); if muted { music?.pause(); effects.values.flatMap{$0}.forEach{$0.stop()} } else { music?.play() } }
    func focus(_ active: Bool) { if active && !muted { music?.play() } else { music?.pause() } }
}

final class GardenView: NSView {
    var game = Game()
    let audio: Audio
    var previewMode = false
    var atlas: NSImage?
    var selected: Cell?; var placing: Cat?; var hover: Cell?
    var showRoute = true
    var message = "Welcome, commander. Pick a cat and guard the garden."
    var timer: Timer?; var lastTick=ProcessInfo.processInfo.systemUptime; var saveClock=0.0
    var buttons: [(NSRect,String,Bool)] = []
    let board = NSRect(x:32,y:150,width:640,height:640)
    var scale: CGFloat { min(bounds.width/1120,bounds.height/860) }
    var origin: NSPoint { NSPoint(x:(bounds.width-1120*scale)/2,y:(bounds.height-860*scale)/2) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var saveURL: URL {
        let fm=FileManager.default
        let base=fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Purrimeter",isDirectory:true)
        try? fm.createDirectory(at:base,withIntermediateDirectories:true)
        return base.appendingPathComponent("save.json")
    }
    init(frame: NSRect, preview: Bool = false) {
        audio=Audio(silent:preview); previewMode=preview
        super.init(frame:frame)
        atlas=NSImage(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("characters.png"))
        if !preview, let data=try? Data(contentsOf:saveURL) {
            do { try game.restore(data); message="Welcome back. Your garden is saved. Resume when ready." }
            catch { message="The saved game could not be loaded. A fresh garden is ready." }
        }
        connectSound()
        if preview { return }
        timer=Timer.scheduledTimer(withTimeInterval:1.0/60,repeats:true) { [weak self] _ in self?.tick() }
    }
    required init?(coder:NSCoder) { fatalError() }
    func connectSound() { game.onSound = { [weak self] name in self?.audio.play(name) } }
    func save() {
        if previewMode { return }
        do { try game.encode().write(to:saveURL,options:.atomic) }
        catch { message="Could not save this game: \(error.localizedDescription)" }
    }
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime; let dt=min(0.05,now-lastTick); lastTick=now
        game.step(dt); saveClock += dt
        if saveClock > 4 { save(); saveClock=0 }
        needsDisplay=true
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); trackingAreas.forEach{removeTrackingArea($0)}
        addTrackingArea(NSTrackingArea(rect:bounds,options:[.activeInKeyWindow,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self))
    }
    func point(_ event:NSEvent) -> NSPoint { let p=convert(event.locationInWindow,from:nil); return NSPoint(x:(p.x-origin.x)/scale,y:(p.y-origin.y)/scale) }
    func cell(_ p:NSPoint) -> Cell? { guard board.contains(p) else { return nil }; return Cell(x:Int((p.x-board.minX)/40),y:Int((p.y-board.minY)/40)) }
    override func mouseMoved(with event:NSEvent) { hover=cell(point(event)); needsDisplay=true }
    override func mouseExited(with event:NSEvent) { hover=nil; needsDisplay=true }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self); let p=point(event)
        if let b=buttons.last(where:{$0.0.contains(p)}) { if b.2 { act(b.1) }; return }
        if let c=cell(p) {
            if game.towers.contains(where:{$0.cell==c}) { selected=c; placing=nil }
            else if let kind=placing {
                if let error=game.placementError(c,kind) { message=error }
                else { _=game.build(kind,at:c); message="\(kind.name) reporting for garden duty."; save() }
            } else { selected=nil }
        }
        needsDisplay=true
    }
    override func keyDown(with event:NSEvent) {
        switch event.keyCode {
        case 49: act("pause")
        case 53: placing=nil; selected=nil
        case 18: act("cat:bolt")
        case 19: act("cat:cannon")
        case 20: act("cat:frost")
        default: super.keyDown(with:event)
        }
    }
    func act(_ id:String) {
        if id.hasPrefix("cat:"), let cat=Cat(rawValue:String(id.dropFirst(4))) { placing=cat; selected=nil; message="Click an empty tile to place \(cat.name). Esc cancels." }
        else { switch id {
        case "pause": if game.outcome == .playing { game.paused.toggle(); message=game.paused ? "Tactical pause. Build, repair, or rethink your maze." : "Back on patrol." }
        case "speed": game.speed=game.speed == 1 ? 2 : 1
        case "route": showRoute.toggle()
        case "sound": audio.toggle()
        case "wave": game.startWave(); message="Wave \(game.wave): \(Wave.all[max(0,game.wave-1)].title)"
        case "upgrade": if let s=selected { _=game.upgrade(at:s) }
        case "repair": if let s=selected { _=game.repair(at:s) }
        case "sell": if let s=selected { _=game.sell(at:s); selected=nil }
        case "new":
            let oldPause=game.paused; game.paused=true
            let alert=NSAlert(); alert.messageText="Start a fresh garden?"; alert.informativeText="Your current run will be replaced."; alert.addButton(withTitle:"New Game"); alert.addButton(withTitle:"Keep Playing")
            if alert.runModal() == .alertFirstButtonReturn { game=Game(); connectSound(); selected=nil; placing=nil; message="A fresh garden. A new patrol." }
            else { game.paused=oldPause }
        default: break
        } }
        save(); needsDisplay=true
    }
    func box(_ r:NSRect,_ color:NSColor,_ radius:CGFloat=0) {
        color.setFill(); if radius > 0 { NSBezierPath(roundedRect:r,xRadius:radius,yRadius:radius).fill() } else { r.fill() }
    }
    func line(_ points:[NSPoint],_ color:NSColor,_ width:CGFloat=1) {
        guard let first=points.first else{return}; color.setStroke(); let p=NSBezierPath(); p.lineWidth=width; p.move(to:first); for point in points.dropFirst(){p.line(to:point)}; p.stroke()
    }
    func text(_ string:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat=14,_ color:NSColor=cream,_ bold:Bool=false, width:CGFloat=1000) {
        let style=NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        let attrs:[NSAttributedString.Key:Any] = [.font:NSFont.monospacedSystemFont(ofSize:size,weight:bold ? .bold : .regular),.foregroundColor:color,.paragraphStyle:style]
        (string as NSString).draw(in:NSRect(x:x,y:y,width:width,height:120),withAttributes:attrs)
    }
    func button(_ title:String,_ rect:NSRect,_ id:String,_ enabled:Bool=true,_ active:Bool=false) {
        box(rect, active ? mint : panelColor,6)
        if active { text(title,rect.minX+12,rect.minY+10,13,ink,true,width:rect.width-20) }
        else { text(title,rect.minX+12,rect.minY+10,13,enabled ? cream : muted.withAlphaComponent(0.45),true,width:rect.width-20) }
        buttons.append((rect,id,enabled))
    }
    func sprite(row:Int,frame:Int,rect:NSRect,alpha:CGFloat=1) {
        guard let atlas else{return}
        // Image generation produced uneven gutters. Explicit source bounds keep
        // neighboring effects and other rows out of each animation frame.
        let bands: [(CGFloat,CGFloat)] = [(34,236),(263,480),(510,746),(802,940),(980,1138),(1150,1357),(1360,1607)]
        let columns: [[CGFloat]] = [
            [8,238,472,746,948], [0,234,466,744,948], [0,237,472,750,948],
            [0,237,474,718,948], [0,239,478,732,948], [0,240,478,730,948], [0,237,474,726,948]
        ]
        let (top,bottom)=bands[row]; let left=columns[row][frame%4], right=columns[row][frame%4+1]
        let src=NSRect(x:left,y:atlas.size.height-bottom,width:right-left,height:bottom-top)
        let ratio=min(rect.width/260,rect.height/250)
        let target=NSRect(x:rect.midX-src.width*ratio/2,y:rect.maxY-src.height*ratio,width:src.width*ratio,height:src.height*ratio)
        NSGraphicsContext.current?.imageInterpolation = .none
        atlas.draw(in:target,from:src,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none.rawValue])
    }
    func center(_ c:Cell) -> NSPoint { NSPoint(x:board.minX+CGFloat(c.x)*40+20,y:board.minY+CGFloat(c.y)*40+20) }
    override func draw(_ dirtyRect:NSRect) {
        box(bounds,ink)
        NSGraphicsContext.saveGraphicsState()
        let transform=NSAffineTransform(); transform.translateX(by:origin.x,yBy:origin.y); transform.scale(by:scale); transform.concat()
        buttons=[]
        text("PURRIMETER",32,25,34,cream,true)
        text("THE GARDEN GUARD",34,69,11,mint,true)
        text("A small garden. A very serious cat problem.",32,108,13,muted)
        stat("COINS",String(game.coins),400, gold)
        stat("LIVES",String(game.lives),500,NSColor.systemPink)
        stat("WAVE","\(game.wave)/20",590,mint)
        button(game.paused ? "▶ Resume" : "Ⅱ Pause",NSRect(x:716,y:32,width:132,height:38),"pause",game.outcome == .playing,game.paused)
        button(game.speed == 1 ? "1× Speed" : "2× Speed",NSRect(x:858,y:32,width:108,height:38),"speed")
        button(audio.muted ? "♫ Off" : "♫ On",NSRect(x:976,y:32,width:110,height:38),"sound")
        text("SPACE pause · 1/2/3 cats · ESC cancel",716,84,11,muted)
        drawBoard()
        drawSidebar()
        text(message,32,807,12,cream,width:640)
        NSGraphicsContext.restoreGraphicsState()
    }
    func stat(_ title:String,_ value:String,_ x:CGFloat,_ color:NSColor) { text(title,x,32,10,muted,true); text(value,x,51,25,color,true) }
    func drawBoard() {
        box(board.insetBy(dx:-5,dy:-5),NSColor(calibratedRed:0.26,green:0.36,blue:0.30,alpha:1),4)
        for y in 0..<16 { for x in 0..<16 {
            let r=NSRect(x:board.minX+CGFloat(x)*40,y:board.minY+CGFloat(y)*40,width:40,height:40)
            let light=(x+y)%2==0
            box(r,NSColor(calibratedRed:light ? 0.18 : 0.17,green:light ? 0.27 : 0.25,blue:light ? 0.23 : 0.21,alpha:1))
            if (x*13+y*7)%9 == 0 { box(NSRect(x:r.minX+8,y:r.minY+27,width:2,height:4),NSColor(calibratedRed:0.25,green:0.35,blue:0.28,alpha:1)); box(NSRect(x:r.minX+11,y:r.minY+25,width:2,height:5),NSColor(calibratedRed:0.25,green:0.35,blue:0.28,alpha:1)) }
        } }
        for (c,label,col) in [(Cell.entrance,"IN",gold),(Cell.exit,"OUT",mint)] {
            let p=center(c); box(NSRect(x:p.x-20,y:p.y-20,width:40,height:40),col.withAlphaComponent(0.22))
            text(label,p.x-15,p.y-7,11,col,true)
        }
        if showRoute {
            let path=game.routePreview()
            let isBreach=path.contains{c in game.towers.contains{$0.cell==c}}
            for c in path.dropFirst().dropLast() { let p=center(c); box(NSRect(x:p.x-2,y:p.y-2,width:4,height:4),isBreach ? gold.withAlphaComponent(0.5) : mint.withAlphaComponent(0.28)) }
        }
        let inspection=selected.flatMap { c in game.towers.first{$0.cell==c} }
        if let t=inspection { drawRange(t.cell,t.range,accent(t.kind)) }
        if let c=hover, let cat=placing {
            let p=center(c); let valid=game.placementError(c,cat)==nil
            drawRange(c,cat.range,valid ? mint : .systemRed)
            box(NSRect(x:p.x-20,y:p.y-20,width:40,height:40),(valid ? mint : NSColor.systemRed).withAlphaComponent(0.3))
            sprite(row:cat.row,frame:0,rect:NSRect(x:p.x-21,y:p.y-25,width:42,height:42),alpha:0.7)
        }
        for t in game.towers {
            let p=center(t.cell)
            box(NSRect(x:p.x-17,y:p.y+10,width:34,height:8),NSColor.black.withAlphaComponent(0.2),4)
            if t.cell==selected { let r=NSBezierPath(rect:NSRect(x:p.x-20,y:p.y-20,width:40,height:40)); mint.setStroke(); r.lineWidth=2; r.stroke() }
            let frame=t.flash > 0 ? 2 : [0,1,3,1][Int(game.elapsed*3 + Double(t.cell.x))%4]
            sprite(row:t.kind.row,frame:frame,rect:NSRect(x:p.x-22,y:p.y-25,width:44,height:44))
            for i in 0..<t.level { box(NSRect(x:p.x-6+CGFloat(i)*5,y:p.y+15,width:3,height:3),gold) }
            if t.health < t.maxHealth-0.1 { healthBar(p.x-15,p.y-21,30,t.health/t.maxHealth,mint) }
        }
        for e in game.enemies.sorted(by:{$0.y < $1.y}) {
            let p=NSPoint(x:board.minX+CGFloat(e.x)*40+20,y:board.minY+CGFloat(e.y)*40+20)
            let size:CGFloat=e.kind == .brute ? 40 : 34
            box(NSRect(x:p.x-12,y:p.y+8,width:24,height:7),NSColor.black.withAlphaComponent(0.25),3)
            sprite(row:e.kind.row,frame:e.attackFlash > 0 ? 2 : Int(game.elapsed * e.kind.speed * 6 + Double(e.id))%4,rect:NSRect(x:p.x-size/2,y:p.y-size/2-4,width:size,height:size))
            if e.slow > 0 { let halo=NSBezierPath(ovalIn:NSRect(x:p.x-16,y:p.y-16,width:32,height:32)); NSColor.cyan.withAlphaComponent(0.5).setStroke(); halo.lineWidth=2; halo.stroke() }
            healthBar(p.x-12,p.y-size/2-7,24,e.health/e.maxHealth,e.slow > 0 ? .cyan : .systemPink)
        }
        for shot in game.shots {
            let a=NSPoint(x:board.minX+CGFloat(shot.x)*40+20,y:board.minY+CGFloat(shot.y)*40+20)
            let b=NSPoint(x:board.minX+CGFloat(shot.tx)*40+20,y:board.minY+CGFloat(shot.ty)*40+20)
            line([a,b],accent(shot.kind).withAlphaComponent(shot.life/0.2),shot.kind == .cannon ? 4 : 2)
            if shot.kind == .cannon { let radius=CGFloat(1-shot.life/0.2)*45+4; let blast=NSBezierPath(ovalIn:NSRect(x:b.x-radius,y:b.y-radius,width:radius*2,height:radius*2)); accent(.cannon).withAlphaComponent(shot.life/0.2).setStroke(); blast.lineWidth=3; blast.stroke() }
        }
        if game.outcome != .playing {
            box(board,ink.withAlphaComponent(0.78))
            let won=game.outcome == .won
            text(won ? "GARDEN SECURED!" : "THE GARDEN FELL",110,380,34,won ? mint : gold,true)
            text(won ? "Twenty waves. Three whiskered legends." : "Even great cats need another try.",115,438,15,cream)
            text("\(game.kills) enemies defeated · Wave \(game.wave)",160,480,15,muted)
            button("Play again",NSRect(x:260,y:536,width:170,height:44),"new",true,true)
        } else if game.paused {
            box(NSRect(x:246,y:158,width:214,height:29),ink.withAlphaComponent(0.9),4)
            text("Ⅱ TACTICAL PAUSE",264,164,14,mint,true)
        }
    }
    func drawRange(_ cell:Cell,_ radius:Double,_ color:NSColor) {
        NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect:board).addClip()
        let p=center(cell); let r=CGFloat(radius)*40
        let circle=NSBezierPath(ovalIn:NSRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2))
        color.withAlphaComponent(0.07).setFill(); circle.fill(); color.withAlphaComponent(0.45).setStroke(); circle.lineWidth=1.5; circle.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    func healthBar(_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ fraction:Double,_ color:NSColor) { box(NSRect(x:x,y:y,width:width,height:3),ink); box(NSRect(x:x,y:y,width:width*max(0,min(1,fraction)),height:3),color) }
    func drawSidebar() {
        text("RECRUIT YOUR PATROL",716,122,12,mint,true)
        for (i,cat) in Cat.allCases.enumerated() {
            let y:CGFloat=150+CGFloat(i)*81; let r=NSRect(x:716,y:y,width:370,height:72)
            box(r,placing==cat ? NSColor(calibratedRed:0.20,green:0.28,blue:0.25,alpha:1) : panelColor,7)
            sprite(row:cat.row,frame:[0,1,3,1][Int(game.elapsed*2)%4],rect:NSRect(x:725,y:y+6,width:59,height:59))
            text(cat.name,797,y+10,16,cream,true); text(cat.role,797,y+35,10,muted)
            text("\(cat.cost)c",1024,y+10,15,game.coins>=cat.cost ? gold : muted,true)
            buttons.append((r,"cat:\(cat.rawValue)",game.outcome == .playing))
        }
        if let c=selected, let t=game.towers.first(where:{$0.cell==c}) {
            text("\(t.kind.name.uppercased()) · LV \(t.level)",716,407,15,accent(t.kind),true)
            text("HP \(Int(ceil(t.health)))/\(Int(t.maxHealth))   DMG \(Int(t.damage))   RNG \(String(format:"%.1f",t.range))",716,435,12,muted)
            healthBar(716,462,370,t.health/t.maxHealth,mint)
            button(t.level < 3 ? "Upgrade · \(t.upgradeCost)c" : "Max level",NSRect(x:716,y:482,width:185,height:38),"upgrade",t.level<3 && game.coins>=t.upgradeCost && game.outcome == .playing)
            button("Repair · \(t.repairCost)c",NSRect(x:911,y:482,width:175,height:38),"repair",t.health<t.maxHealth-0.01 && game.coins>=t.repairCost && game.outcome == .playing)
            button("Sell · +\(t.refund)c",NSRect(x:716,y:530,width:185,height:38),"sell",game.outcome == .playing)
        } else {
            text(placing == nil ? "BUILD A BETTER MAZE" : "\(placing!.name.uppercased())",716,407,15,cream,true)
            text(placing == nil ? "Cats block the path. Enemies take the shortest open route. Seal it completely and they will fight their way through." : "\(placing!.role)\nRange \(String(format:"%.1f",placing!.range)) tiles · Health \(Int(placing!.hp))\nClick a clear tile to recruit.\nYou can build while paused.",716,437,13,muted,width:360)
            text("Click any cat to upgrade, repair, or sell.",716,547,11,mint,width:370)
        }
        box(NSRect(x:716,y:590,width:370,height:138),panelColor,7)
        let index=min(19,game.active ? max(0,game.wave-1) : game.wave)
        let next=Wave.all[index]
        text(game.active ? "ON THE FIELD · \(game.enemies.count) ENEMIES" : game.wave == 20 ? "PATROL COMPLETE" : "UP NEXT · WAVE \(index+1)",732,605,11,mint,true)
        text(next.title,732,631,16,cream,true,width:340)
        text(next.preview,732,660,12,muted,width:338)
        button(game.active ? "Wave in progress · \(game.spawned)/\(next.foes.count)" : "Next wave  →",NSRect(x:716,y:742,width:370,height:46),"wave",game.canStart,game.canStart)
        button(showRoute ? "Route: on" : "Route: off",NSRect(x:716,y:804,width:166,height:36),"route")
        button("New game",NSRect(x:896,y:804,width:190,height:36),"new")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!; var garden: GardenView!
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu(); let appItem=NSMenuItem(); menu.addItem(appItem)
        let submenu=NSMenu(); submenu.addItem(withTitle:"Quit Purrimeter",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); appItem.submenu=submenu; NSApp.mainMenu=menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1120,height:860),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Purrimeter — The Garden Guard"; window.minSize=NSSize(width:900,height:720); window.backgroundColor=ink; window.delegate=self
        garden=GardenView(frame:NSRect(x:0,y:0,width:1120,height:860),preview:CommandLine.arguments.contains("--smoke-test")); garden.autoresizingMask=[.width,.height]; window.contentView=garden
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(garden); NSApp.activate(ignoringOtherApps:true)
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { self.smokeTest() }
        }
    }
    func smokeTest() {
        func verify(_ condition: Bool, _ label: String) {
            if !condition { print("FAIL: \(label)"); exit(1) }
            print("PASS: \(label)")
        }
        verify(window.isVisible && garden.window != nil,"native window initialized and visible")
        garden.game.paused=false
        garden.act("cat:bolt"); verify(garden.placing == .bolt,"recruit control selects Tabby")
        let cell=Cell(x:3,y:7)
        verify(garden.game.build(.bolt,at:cell),"recruit action builds cat")
        garden.selected=cell; garden.act("upgrade")
        verify(garden.game.towers[0].level == 2,"inspector upgrade action")
        garden.game.towers[0].health *= 0.5; garden.act("repair")
        verify(garden.game.towers[0].health == garden.game.towers[0].maxHealth,"inspector repair action")
        garden.act("pause"); verify(garden.game.paused,"pause control")
        garden.act("speed"); verify(garden.game.speed == 2,"speed control")
        garden.act("route"); verify(!garden.showRoute,"route control")
        garden.act("wave"); verify(garden.game.active && !garden.game.paused,"next wave starts and resumes")
        garden.act("sell"); verify(garden.game.towers.isEmpty,"sell control")
        for name in ["garden","bolt","cannon","frost","coin","build","upgrade","wave","clear","escape","break","win","lose"] {
            let player=try! AVAudioPlayer(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("\(name).wav"))
            verify(player.duration > 0 && player.prepareToPlay(),"audio decodes: \(name)")
        }
        verify(garden.atlas != nil,"sprite atlas loads")
        print("Native app smoke test passed.")
        NSApp.terminate(nil)
    }
    func windowDidResignKey(_ notification:Notification) { garden.game.paused=true; garden.audio.focus(false); garden.save() }
    func windowDidBecomeKey(_ notification:Notification) { garden?.audio.focus(true) }
    func applicationWillTerminate(_ notification:Notification) { garden.save() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { true }
}
@main struct Purrimeter {
    static func main() {
        let app=NSApplication.shared
        if let flag=CommandLine.arguments.firstIndex(of:"--render-preview"), CommandLine.arguments.count > flag+1 {
            let view=GardenView(frame:NSRect(x:0,y:0,width:1120,height:860),preview:true)
            view.game.coins=1200
            for (i,cat) in Cat.allCases.enumerated() {
                _=view.game.build(cat,at:Cell(x:4+i*3,y:7))
                _=view.game.build(cat,at:Cell(x:4+i*3,y:9))
            }
            view.game.wave=7; view.game.active=true; view.game.elapsed=3.2
            for (i,foe) in Foe.allCases.enumerated() {
                var enemy=Enemy(id:i,kind:foe,wave:7); enemy.cell=Cell(x:3+i*2,y:8); view.game.enemies.append(enemy)
            }
            view.selected=Cell(x:4,y:7)
            guard let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { exit(1) }
            view.cacheDisplay(in:view.bounds,to:rep)
            try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[flag+1]))
            print("Rendered preview"); return
        }
         let delegate=AppDelegate(); app.delegate=delegate; app.run(); withExtendedLifetime(delegate){} }
}
