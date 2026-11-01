class_name DraftTransaction
extends RefCounted
## Stage changes without touching the live garden. Persist before publishing.
static func prepare(g: Session, choice: String = "") -> Session:
	var next := Session.new()
	if not next.restore(g.snapshot()): return null
	if not (next.rebirth() if choice.is_empty() else next.choose_draft(choice)): return null
	return next

static func commit(g: Session, next: Session, persist: Callable) -> bool:
	if next==null or persist.call(next)!=OK: return false
	return publish(g,next)

static func publish(g: Session, next: Session) -> bool:
	if not g.restore(next.snapshot()): return false
	g.changed.emit()
	return true
