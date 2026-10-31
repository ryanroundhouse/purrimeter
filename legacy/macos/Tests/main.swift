import Foundation
var checks=0
func check(_ condition: @autoclosure () -> Bool,_ label:String) { checks += 1; if !condition() { print("FAIL: \(label)"); exit(1) }; print("PASS: \(label)") }
let empty=Game()
check(empty.routePreview().count == 16,"empty board shortest route is 15 steps")
check(!empty.build(.bolt,at:.entrance) && !empty.build(.bolt,at:.exit),"gate placement rejected")
check(empty.build(.bolt,at:Cell(x:4,y:8)),"tower purchase succeeds")
check(empty.coins==150,"purchase spends exact cost")
check(empty.routePreview().count==18,"open path detours around tower")
check(!empty.routePreview().contains(Cell(x:4,y:8)),"open route never destroys faster shortcut")
let wall=Game(); wall.coins=10000
for y in 0..<16 { _=wall.build(.cannon,at:Cell(x:5,y:y)) }
wall.towers[wall.towers.firstIndex{$0.cell.y==7}!].health=1
wall.invalidateRoutes()
let route=wall.routePreview()
check(route.contains(Cell(x:5,y:7)),"breach chooses travel plus destruction minimum")
check(!route.contains(Cell(x:5,y:8)),"breach prefers weak nearby tower to strong direct tower")
let cross=Game(); var moving=Enemy(id:0,kind:.grunt,wave:1); moving.cell=Cell(x:4,y:8); moving.next=Cell(x:5,y:8); moving.progress=0.5; cross.enemies=[moving]
check(!cross.build(.bolt,at:Cell(x:4,y:8)) && !cross.build(.bolt,at:Cell(x:5,y:8)),"both crossing cells reserved")
let money=Game(); money.coins=1000; let c=Cell(x:2,y:2); _=money.build(.bolt,at:c); money.towers[0].health=80
check(money.upgrade(at:c),"upgrade succeeds")
check(abs(money.towers[0].health/money.towers[0].maxHealth-0.5)<0.001,"upgrade preserves health percentage")
check(money.towers[0].refund==38,"resale floors health-scaled investment")
let spent=money.towers[0].spent; let rc=money.towers[0].repairCost; let before=money.coins
check(money.repair(at:c),"repair succeeds")
check(money.coins==before-rc && money.towers[0].health==money.towers[0].maxHealth,"repair cost and health exact")
check(money.towers[0].spent==spent,"repair does not inflate resale investment")
_=money.upgrade(at:c); check(!money.upgrade(at:c),"level three is maximum")
let refund=money.towers[0].refund, coins=money.coins
check(money.sell(at:c) && money.coins==coins+refund && money.towers.isEmpty,"selling refunds and clears tile")
let combat=Game(); combat.coins=10000
for x in 1...14 { _=combat.build(.bolt,at:Cell(x:x,y:7)) }
combat.startWave(); let coinsBefore=combat.coins
for _ in 0..<3000 { combat.step(1/60) }
check(combat.kills==8 && combat.lives==20 && !combat.active,"first wave kills and clears")
check(combat.coins==coinsBefore+64,"all kill bounties paid once")
let pauseData=try combat.encode(); combat.paused=true; combat.step(0.05)
let afterPause = try combat.encode()
check(afterPause==pauseData,"tactical pause freezes simulation")
let restored=Game(); try restored.restore(pauseData)
check(restored.paused && restored.coins==combat.coins && restored.towers.count==combat.towers.count,"save restores run paused")
let loss=Game(); loss.startWave()
for _ in 0..<10000 { loss.step(1/60) }
check(loss.lives==12 && loss.canStart,"escapes cost one life and wave ends")
loss.wave=19; loss.lives=1; loss.startWave()
for _ in 0..<3000 { loss.step(1/60) }
check(loss.outcome == .lost && !loss.canStart,"zero lives loses and prevents next wave")
let win=Game(); win.wave=19; win.startWave(); win.spawned=Wave.all[19].foes.count; win.step(0.01)
check(win.outcome == .won,"final wave cleared wins")
let attack=Game(); attack.coins=10000
for y in 0..<16 { _=attack.build(.frost,at:Cell(x:1,y:y)) }
for i in attack.towers.indices { attack.towers[i].cooldown=1000; attack.towers[i].health=10 }
attack.startWave(); attack.spawned=Wave.all[0].foes.count
var breaker=Enemy(id:999,kind:.breaker,wave:1); breaker.cell = .entrance; attack.enemies=[breaker]
for _ in 0..<60 { attack.step(1/60) }
check(attack.towers.count==15,"blocked enemy destroys a tower")
check(attack.enemies[0].next != nil || attack.enemies[0].cell.x>0,"enemy moves through breach")
let mid=Game(); mid.startWave(); for _ in 0..<100 {mid.step(1/60)}
let midSave=try mid.encode(); let resumed=Game(); try resumed.restore(midSave); resumed.paused=false
for _ in 0..<500 { mid.step(1/60); resumed.step(1/60) }
let uninterruptedData=try mid.encode(), resumedData=try resumed.encode()
check(uninterruptedData==resumedData,"mid-wave save resumes identically")
check(Wave.all.count==20 && Wave.all.allSatisfy{!$0.foes.isEmpty && $0.gap>0},"twenty valid handcrafted waves")
print("\(checks) checks passed.")

let splash=Game(); splash.coins=1000; _=splash.build(.cannon,at:Cell(x:3,y:7)); splash.startWave(); splash.spawned=Wave.all[0].foes.count
for i in 0..<2 { var e=Enemy(id:i,kind:.brute,wave:1); e.cell=Cell(x:3+i,y:8); splash.enemies.append(e) }
splash.step(0.01)
check(splash.enemies.allSatisfy{$0.health==114},"cannon splash damages both nearby enemies")
let frost=Game(); frost.coins=1000; _=frost.build(.frost,at:Cell(x:3,y:7)); _=frost.build(.frost,at:Cell(x:4,y:7)); frost.startWave(); frost.spawned=Wave.all[0].foes.count
var chilled=Enemy(id:1,kind:.brute,wave:1); chilled.cell=Cell(x:3,y:8); frost.enemies=[chilled]; frost.step(0.01)
check(abs(frost.enemies[0].speed-Foe.brute.speed*0.52)<0.001,"multiple Frost hits do not stack slow strength")
let target=Game(); target.coins=1000; _=target.build(.bolt,at:Cell(x:8,y:7)); target.startWave(); target.spawned=Wave.all[0].foes.count
var close=Enemy(id:1,kind:.grunt,wave:1); close.cell=Cell(x:9,y:8)
var fast=Enemy(id:2,kind:.runner,wave:1); fast.cell=Cell(x:8,y:8)
target.enemies=[close,fast]; target.step(0.01)
check(target.enemies[1].health < Foe.runner.hp && target.enemies[0].health == Foe.grunt.hp,"target priority uses escape time rather than geometric distance")
let groupAttack=Game(); groupAttack.coins=10000
for y in 0..<16 { _=groupAttack.build(.cannon,at:Cell(x:1,y:y)) }
for i in groupAttack.towers.indices { groupAttack.towers[i].cooldown=1000 }
groupAttack.startWave(); groupAttack.spawned=Wave.all[0].foes.count
groupAttack.enemies=[Enemy(id:1,kind:.breaker,wave:1),Enemy(id:2,kind:.breaker,wave:1)]
groupAttack.step(0.05)
check(abs(groupAttack.towers.first{$0.cell.y==8}!.health-(260-4.8))<0.001,"enemies combine damage against a shared blocker")
let campaign=Game()
for x in [2,5,8,11] { _=campaign.build(.bolt,at:Cell(x:x,y:7)) }
for _ in 1...20 {
    // An affordable, repeatable reference strategy: upgrade scouts, then add
    // splash and slowing support. Uses the same public economy as the player.
    for t in campaign.towers where t.level<3 { _=campaign.upgrade(at:t.cell) }
    for x in [3,6,9,12,1,14] {
        let c=Cell(x:x,y:9)
        if !campaign.towers.contains(where:{$0.cell==c}) { _=campaign.build(x%2==0 ? .frost : .cannon,at:c) }
    }
    campaign.startWave()
    for _ in 0..<24000 { campaign.step(1/60); if !campaign.active { break } }
    print("Campaign wave \(campaign.wave): lives=\(campaign.lives), coins=\(campaign.coins), kills=\(campaign.kills)")
    if campaign.outcome != .playing { break }
}
check(campaign.outcome == .won,"full campaign is winnable using earned coins")
print("All \(checks) checks passed.")
