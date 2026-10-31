class_name Amount
extends RefCounted
## Positive amounts in log space avoid overflow in endless exponential progression.
## Approximately 15 significant digits; fractional bounties are retained.
const ZERO := -1.0e100
var power: float = ZERO

static func of(value: float) -> Amount:
	return from_power(log(value) / log(10.0) if value > 0 else ZERO)

static func from_power(value: float) -> Amount:
	var result := Amount.new()
	result.power = value
	return result

func copy() -> Amount:
	return from_power(power)

func is_zero() -> bool:
	return power <= ZERO * 0.5

func times(value: float) -> Amount:
	return from_power(power + log(value) / log(10.0)) if value > 0 and not is_zero() else of(0)

func plus(other: Amount) -> Amount:
	if is_zero(): return other.copy()
	if other.is_zero(): return copy()
	var high := maxf(power, other.power)
	var low := minf(power, other.power)
	return from_power(high + log(1.0 + pow(10.0, low - high)) / log(10.0))

func enough(other: Amount) -> bool:
	return power + 1.0e-12 >= other.power

func minus(other: Amount) -> Amount:
	if other.is_zero(): return copy()
	if not enough(other) or absf(power - other.power) < 1.0e-12: return of(0)
	return from_power(power + log(1.0 - pow(10.0, other.power - power)) / log(10.0))

func numeric() -> float:
	return 0.0 if is_zero() else pow(10.0, minf(power, 300.0))

func label() -> String:
	if is_zero(): return "0"
	if power < 3:
		var value := numeric()
		return str(int(round(value))) if absf(value-round(value))<1e-7 else "%.1f"%value
	var exponent := int(floor(power))
	var suffix := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var group := exponent / 3
	if group < suffix.size(): return "%.1f%s" % [pow(10, power - group * 3), suffix[group]]
	return "%.2fe%d" % [pow(10, power - exponent), exponent]
