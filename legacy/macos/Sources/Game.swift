import Foundation

struct Cell: Codable, Hashable {
    var x: Int; var y: Int
    var index: Int { y * 16 + x }
    static let entrance = Cell(x: 0, y: 8)
    static let exit = Cell(x: 15, y: 8)
    var neighbors: [Cell] {
        [Cell(x:x+1,y:y), Cell(x:x,y:y-1), Cell(x:x,y:y+1), Cell(x:x-1,y:y)].filter { (0..<16).contains($0.x) && (0..<16).contains($0.y) }
    }
}
enum Cat: String, Codable, CaseIterable {
    case bolt, cannon, frost
    var name: String { switch self { case .bolt: return "Tabby Scout"; case .cannon: return "Chunky Gunner"; case .frost: return "Siamese Sage" } }
    var role: String { switch self { case .bolt: return "BOLT · Quick single-target shots"; case .cannon: return "CANNON · Explosive splash"; case .frost: return "FROST · Slows the swarm" } }
    var cost: Int { switch self { case .bolt: return 50; case .cannon: return 80; case .frost: return 70 } }
    var row: Int { Self.allCases.firstIndex(of:self)! }
    var hp: Double { switch self { case .bolt: return 160; case .cannon: return 260; case .frost: return 180 } }
    var damage: Double { switch self { case .bolt: return 14; case .cannon: return 36; case .frost: return 5 } }
    var interval: Double { switch self { case .bolt: return 0.48; case .cannon: return 1.65; case .frost: return 0.85 } }
    var range: Double { switch self { case .bolt: return 3.4; case .cannon: return 3.0; case .frost: return 2.8 } }
}
enum Foe: String, Codable, CaseIterable {
    case grunt, runner, brute, breaker
    var name: String { rawValue.capitalized }
    var row: Int { 3 + Self.allCases.firstIndex(of:self)! }
    var hp: Double { switch self { case .grunt: return 38; case .runner: return 27; case .brute: return 150; case .breaker: return 80 } }
    var speed: Double { switch self { case .grunt: return 1.25; case .runner: return 2.1; case .brute: return 0.78; case .breaker: return 1.05 } }
    var dps: Double { switch self { case .grunt: return 12; case .runner: return 8; case .brute: return 22; case .breaker: return 48 } }
    var reward: Int { switch self { case .grunt: return 8; case .runner: return 9; case .brute: return 20; case .breaker: return 15 } }
}
struct Tower: Codable {
    var cell: Cell; var kind: Cat; var level = 1; var health: Double; var spent: Int; var cooldown = 0.0; var flash = 0.0
    init(_ kind: Cat, _ cell: Cell) { self.kind = kind; self.cell = cell; health = kind.hp; spent = kind.cost }
    var maxHealth: Double { kind.hp * (1 + Double(level-1)*0.55) }
    var damage: Double { kind.damage * pow(1.65,Double(level-1)) }
    var range: Double { kind.range + Double(level-1)*0.35 }
    var interval: Double { kind.interval / (1 + Double(level-1)*0.13) }
    var upgradeCost: Int { Int(Double(kind.cost) * (level == 1 ? 1.2 : 1.8)) }
    var repairCost: Int { max(1,Int(ceil(Double(spent)*0.4*(1-health/maxHealth)))) }
    var refund: Int { max(0,Int(floor(Double(spent)*0.7*health/maxHealth))) }
}
struct Enemy: Codable {
    var id: Int; var kind: Foe; var cell: Cell = .entrance; var next: Cell?; var progress = 0.0
    var health: Double; var maxHealth: Double; var slow = 0.0; var attackFlash = 0.0
    init(id: Int, kind: Foe, wave: Int) { self.id = id; self.kind = kind; maxHealth = kind.hp * (1 + Double(wave-1)*0.09); health = maxHealth }
    var speed: Double { kind.speed * (slow > 0 ? 0.52 : 1) }
    var x: Double { Double(cell.x) + Double((next?.x ?? cell.x)-cell.x)*progress }
    var y: Double { Double(cell.y) + Double((next?.y ?? cell.y)-cell.y)*progress }
}
struct Wave {
    var title: String; var foes: [Foe]; var gap: Double
    static let all: [Wave] = [
        Wave("A squeak in the grass",[(.grunt,8)],0.9),
        Wave("Quick paws",[(.grunt,5),(.runner,5)],0.8),
        Wave("Rat race",[(.runner,8),(.grunt,6)],0.7),
        Wave("Heavy footsteps",[(.grunt,8),(.brute,3)],0.8),
        Wave("The demolition crew",[(.grunt,6),(.breaker,4),(.runner,4)],0.7),
        Wave("Double trouble",[(.runner,8),(.brute,4),(.grunt,6)],0.65),
        Wave("Hammer time",[(.breaker,6),(.grunt,12)],0.6),
        Wave("The long march",[(.brute,7),(.runner,10)],0.65),
        Wave("Purple tide",[(.grunt,24),(.breaker,4)],0.45),
        Wave("Midnight raid",[(.runner,12),(.breaker,7),(.brute,5)],0.55),
        Wave("Steel and squeaks",[(.brute,8),(.grunt,18)],0.5),
        Wave("Green lightning",[(.runner,28),(.breaker,5)],0.38),
        Wave("Heavy machinery",[(.breaker,12),(.brute,8)],0.55),
        Wave("The sandwich",[(.runner,12),(.brute,10),(.runner,12)],0.45),
        Wave("A very bad picnic",[(.grunt,22),(.breaker,10),(.brute,6)],0.4),
        Wave("Rumble in the garden",[(.brute,15),(.runner,16)],0.45),
        Wave("Breach party",[(.breaker,18),(.runner,16)],0.4),
        Wave("No rest for whiskers",[(.grunt,24),(.runner,20),(.brute,8)],0.32),
        Wave("Nine lives",[(.brute,14),(.breaker,16),(.runner,16)],0.35),
        Wave("The last meow",[(.grunt,20),(.breaker,14),(.brute,18),(.runner,24)],0.3)
    ]
    init(_ title: String,_ groups: [(Foe,Int)],_ gap: Double) { self.title=title; self.foes=groups.flatMap { Array(repeating:$0.0,count:$0.1) }; self.gap=gap }
    var preview: String {
        var groups: [(Foe,Int)] = []
        for foe in foes { if groups.last?.0 == foe { groups[groups.count-1].1 += 1 } else { groups.append((foe,1)) } }
        return groups.map { "\($0.1) \($0.0.name)" }.joined(separator:" → ")
    }
}
enum Outcome: String, Codable { case playing, won, lost }
struct Shot { var x: Double; var y: Double; var tx: Double; var ty: Double; var kind: Cat; var life = 0.2 }
struct RouteField {
    var distances: [Double]; var next: [Cell?]
}

// Reverse Dijkstra: entering a tower costs its destruction time. An open field is
// always consulted first, so a faster breach never supersedes an open detour.
enum Pathfinder {
    static func field(towers: [Tower], speed: Double, dps: Double, breach: Bool) -> RouteField {
        var blocked = [Int:Double]()
        for t in towers { blocked[t.cell.index] = t.health }
        var dist = Array(repeating:Double.infinity,count:256)
        var next = Array<Cell?>(repeating:nil,count:256)
        var visited = Array(repeating:false,count:256)
        dist[Cell.exit.index] = 0
        for _ in 0..<256 {
            var u = -1; var best = Double.infinity
            for i in 0..<256 where !visited[i] && dist[i] < best { u=i; best=dist[i] }
            if u < 0 { break }
            visited[u]=true
            let cell = Cell(x:u%16,y:u/16)
            if !breach && blocked[u] != nil { continue }
            let cost = 1/speed + (breach ? (blocked[u] ?? 0)/dps : 0)
            for neighbor in cell.neighbors {
                if !breach && blocked[neighbor.index] != nil { continue }
                let alt = best + cost
                if alt < dist[neighbor.index] { dist[neighbor.index]=alt; next[neighbor.index]=cell }
            }
        }
        return RouteField(distances:dist,next:next)
    }
}

final class Game {
    struct Save: Codable {
        var version = 1; var towers: [Tower]; var enemies: [Enemy]; var coins: Int; var lives: Int
        var wave: Int; var active: Bool; var spawned: Int; var spawnClock: Double; var nextID: Int
        var kills: Int; var elapsed: Double; var outcome: Outcome
    }
    var towers: [Tower] = []; var enemies: [Enemy] = []; var coins = 200; var lives = 20
    var wave = 0; var active = false; var spawned = 0; var spawnClock = 0.0; var nextID = 0
    var kills = 0; var elapsed = 0.0; var outcome = Outcome.playing
    var paused = false; var speed = 1.0; var shots: [Shot] = []
    var onSound: ((String)->Void)?
    private var openField: RouteField?; private var breachFields: [Foe:RouteField] = [:]
    private var routeAge = 0.0
    var canStart: Bool { !active && outcome == .playing && wave < 20 }
    func invalidateRoutes() { openField=nil; breachFields.removeAll(); routeAge=0 }
    func field(for kind: Foe, from cell: Cell) -> RouteField {
        if openField == nil { openField=Pathfinder.field(towers:towers,speed:1,dps:1,breach:false) }
        if openField!.distances[cell.index].isFinite { return openField! }
        if breachFields[kind] == nil { breachFields[kind]=Pathfinder.field(towers:towers,speed:kind.speed,dps:kind.dps,breach:true) }
        return breachFields[kind]!
    }
    func remaining(_ enemy: Enemy) -> Double {
        let start = enemy.next ?? enemy.cell
        let f = field(for:enemy.kind,from:start)
        let d = f.distances[start.index]
        let routeTime = (openField?.distances[start.index].isFinite == true) ? d/enemy.speed : d
        return routeTime + (enemy.next == nil ? 0 : (1-enemy.progress)/enemy.speed)
    }
    func routePreview() -> [Cell] {
        let f=field(for:.grunt,from:.entrance)
        var path: [Cell] = [.entrance]; var cell=Cell.entrance
        for _ in 0..<256 { guard cell != .exit, let n=f.next[cell.index], !path.contains(n) else { break }; path.append(n); cell=n }
        return path
    }
    func placementError(_ cell: Cell, _ kind: Cat) -> String? {
        if outcome != .playing { return "Start a new game to build." }
        if !(0..<16).contains(cell.x) || !(0..<16).contains(cell.y) { return "Place inside the garden." }
        if cell == .entrance || cell == .exit { return "Keep the entrance and exit clear." }
        if towers.contains(where:{$0.cell == cell}) { return "A cat already guards this tile." }
        if enemies.contains(where:{$0.cell == cell || $0.next == cell}) { return "An enemy is crossing this tile." }
        if coins < kind.cost { return "Not enough coins." }
        return nil
    }
    @discardableResult func build(_ kind: Cat, at cell: Cell) -> Bool {
        guard placementError(cell,kind) == nil else { return false }
        coins -= kind.cost; towers.append(Tower(kind,cell)); invalidateRoutes(); onSound?("build"); return true
    }
    @discardableResult func upgrade(at cell: Cell) -> Bool {
        guard outcome == .playing, let i=towers.firstIndex(where:{$0.cell==cell}), towers[i].level < 3, coins >= towers[i].upgradeCost else { return false }
        let fraction=towers[i].health/towers[i].maxHealth; let cost=towers[i].upgradeCost
        coins -= cost; towers[i].spent += cost; towers[i].level += 1; towers[i].health=towers[i].maxHealth*fraction
        invalidateRoutes(); onSound?("upgrade"); return true
    }
    @discardableResult func repair(at cell: Cell) -> Bool {
        guard outcome == .playing, let i=towers.firstIndex(where:{$0.cell==cell}), towers[i].health < towers[i].maxHealth-0.01, coins >= towers[i].repairCost else { return false }
        coins -= towers[i].repairCost; towers[i].health=towers[i].maxHealth; invalidateRoutes(); onSound?("build"); return true
    }
    @discardableResult func sell(at cell: Cell) -> Bool {
        guard outcome == .playing, let i=towers.firstIndex(where:{$0.cell==cell}) else { return false }
        coins += towers[i].refund; towers.remove(at:i); invalidateRoutes(); onSound?("coin"); return true
    }
    func startWave() {
        guard canStart else { return }; wave += 1; spawned=0; spawnClock=0; active=true; paused=false; onSound?("wave")
    }
    func step(_ dt: Double) {
        guard !paused, outcome == .playing else { return }
        let dt=min(dt,0.05)*speed
        elapsed += dt; routeAge += dt
        // Tower health changes affect the cheapest breach, refreshed regularly.
        if routeAge >= 0.35 { breachFields.removeAll(); routeAge=0 }
        shots = shots.compactMap { var s=$0; s.life -= dt; return s.life > 0 ? s : nil }
        for i in towers.indices { towers[i].flash=max(0,towers[i].flash-dt); towers[i].cooldown=max(0,towers[i].cooldown-dt) }
        guard active else { return }
        let plan=Wave.all[wave-1]; spawnClock -= dt
        if spawned < plan.foes.count && spawnClock <= 0 {
            enemies.append(Enemy(id:nextID,kind:plan.foes[spawned],wave:wave)); nextID += 1; spawned += 1; spawnClock += plan.gap
        }
        // Attack before movement; dead enemies cannot escape or attack on this tick.
        let priorities = Dictionary(uniqueKeysWithValues:enemies.map { ($0.id,remaining($0)) })
        for ti in towers.indices where towers[ti].cooldown <= 0 {
            let tower=towers[ti]
            let targets=enemies.indices.filter { enemies[$0].health > 0 && hypot(enemies[$0].x-Double(tower.cell.x),enemies[$0].y-Double(tower.cell.y)) <= tower.range }
            guard let ei=targets.min(by:{ priorities[enemies[$0].id,default:0] < priorities[enemies[$1].id,default:0] }) else { continue }
            let tx=enemies[ei].x, ty=enemies[ei].y
            towers[ti].cooldown=tower.interval; towers[ti].flash=0.22
            shots.append(Shot(x:Double(tower.cell.x),y:Double(tower.cell.y),tx:tx,ty:ty,kind:tower.kind))
            if tower.kind == .cannon {
                for j in enemies.indices where hypot(enemies[j].x-tx,enemies[j].y-ty) <= 1.35 { enemies[j].health -= tower.damage }
            } else {
                enemies[ei].health -= tower.damage
                if tower.kind == .frost { enemies[ei].slow=1.8 }
            }
            onSound?(tower.kind.rawValue)
        }
        let dead=enemies.filter{$0.health <= 0}
        for e in dead { coins += e.kind.reward; kills += 1 }
        if !dead.isEmpty { onSound?("coin") }
        enemies.removeAll{$0.health <= 0}
        var escaped=Set<Int>()
        for ei in enemies.indices {
            enemies[ei].slow=max(0,enemies[ei].slow-dt)
            enemies[ei].attackFlash=max(0,enemies[ei].attackFlash-dt)
            if enemies[ei].next == nil {
                let e=enemies[ei]
                if e.cell == .exit { escaped.insert(e.id); continue }
                let f=field(for:e.kind,from:e.cell)
                if let next=f.next[e.cell.index] {
                    if let ti=towers.firstIndex(where:{$0.cell==next}) {
                        towers[ti].health -= e.kind.dps*dt
                        enemies[ei].attackFlash=0.15
                        if towers[ti].health <= 0 { towers.remove(at:ti); invalidateRoutes(); onSound?("break") }
                    } else { enemies[ei].next=next; enemies[ei].progress=0 }
                }
            }
            if let next=enemies[ei].next {
                enemies[ei].progress += enemies[ei].speed*dt
                if enemies[ei].progress >= 1 {
                    enemies[ei].cell=next; enemies[ei].next=nil; enemies[ei].progress=0
                    if next == .exit { escaped.insert(enemies[ei].id) }
                }
            }
        }
        if !escaped.isEmpty { lives=max(0,lives-escaped.count); enemies.removeAll{escaped.contains($0.id)}; onSound?("escape") }
        if lives == 0 { outcome = .lost; active=false; onSound?("lose") }
        else if spawned == plan.foes.count && enemies.isEmpty { active=false; if wave == 20 { outcome = .won; onSound?("win") } else { onSound?("clear") } }
    }
    func encode() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Save(towers:towers,enemies:enemies,coins:coins,lives:lives,wave:wave,active:active,spawned:spawned,spawnClock:spawnClock,nextID:nextID,kills:kills,elapsed:elapsed,outcome:outcome))
    }
    func restore(_ data: Data) throws {
        let s=try JSONDecoder().decode(Save.self,from:data)
        guard s.version == 1, (0...20).contains(s.wave), s.coins >= 0, (0...20).contains(s.lives), (!s.active || s.wave > 0), s.spawned >= 0,
              s.spawned <= (s.wave > 0 ? Wave.all[s.wave-1].foes.count : 0),
              s.towers.allSatisfy({ (0..<16).contains($0.cell.x) && (0..<16).contains($0.cell.y) && (1...3).contains($0.level) && $0.health > 0 }),
              s.enemies.allSatisfy({ (0..<16).contains($0.cell.x) && (0..<16).contains($0.cell.y) && $0.progress >= 0 && $0.progress < 1 }),
              Set(s.enemies.map(\.id)).count == s.enemies.count else { throw NSError(domain:"Invalid save",code:1) }
        towers=s.towers; enemies=s.enemies; coins=s.coins; lives=s.lives; wave=s.wave; active=s.active; spawned=s.spawned; spawnClock=s.spawnClock; nextID=s.nextID; kills=s.kills; elapsed=s.elapsed; outcome=s.outcome
        paused=true; shots=[]; invalidateRoutes()
    }
}
