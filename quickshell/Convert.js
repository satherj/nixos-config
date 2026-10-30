.pragma library
.import "Calc.js" as Calc
// Unit conversion for the launcher: "<amount> <unit> to|in|as <unit>", where the
// amount can be any Calc expression ("5km in mi", "3*12 in to cm", "20°c to f", "1/2 cup in ml").

// Factor to the dimension's base unit
var units = {
    length: { m: 1, mm: 1e-3, cm: 1e-2, dm: 0.1, km: 1e3, um: 1e-6, "in": 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344, nmi: 1852 },
    mass: { kg: 1, mg: 1e-6, g: 1e-3, t: 1e3, oz: 0.028349523125, lb: 0.45359237, st: 6.35029318 },
    volume: { l: 1, ml: 1e-3, cl: 1e-2, dl: 0.1, m3: 1e3, tsp: 0.00492892159375, tbsp: 0.01478676478125, cup: 0.2365882365, floz: 0.0295735295625, pt: 0.473176473, qt: 0.946352946, gal: 3.785411784 },
    time: { s: 1, ms: 1e-3, min: 60, h: 3600, d: 86400, wk: 604800, mo: 2629746, yr: 31556952 },
    data: { B: 1, bit: 0.125, kB: 1e3, MB: 1e6, GB: 1e9, TB: 1e12, KiB: 1024, MiB: 1048576, GiB: 1073741824, TiB: 1099511627776 },
    speed: { "m/s": 1, "km/h": 1 / 3.6, mph: 0.44704, kn: 1852 / 3600 },
    area: { m2: 1, mm2: 1e-6, cm2: 1e-4, km2: 1e6, ha: 1e4, acre: 4046.8564224, ft2: 0.09290304, in2: 0.00064516 },
    energy: { J: 1, kJ: 1e3, cal: 4.184, kcal: 4184, Wh: 3600, kWh: 3.6e6 }
};

// Other spellings -> the unit names above (matched lowercase; a trailing "s" is also tried)
var aliases = {
    meter: "m", metre: "m", millimeter: "mm", millimetre: "mm", centimeter: "cm", centimetre: "cm",
    kilometer: "km", kilometre: "km", inch: "in", inches: "in", '"': "in", foot: "ft", feet: "ft", "'": "ft",
    yard: "yd", mile: "mi", "µm": "um", micron: "um",
    gram: "g", kilogram: "kg", kilo: "kg", ton: "t", tonne: "t", ounce: "oz", pound: "lb", lbs: "lb", stone: "st",
    liter: "l", litre: "l", milliliter: "ml", millilitre: "ml", teaspoon: "tsp", tablespoon: "tbsp",
    "fl oz": "floz", pint: "pt", quart: "qt", gallon: "gal",
    sec: "s", second: "s", millisecond: "ms", minute: "min", mins: "min", hr: "h", hrs: "h", hour: "h",
    day: "d", week: "wk", month: "mo", year: "yr", y: "yr",
    b: "B", byte: "B", kb: "kB", mb: "MB", gb: "GB", tb: "TB", kib: "KiB", mib: "MiB", gib: "GiB", tib: "TiB",
    "m/s": "m/s", mps: "m/s", kmh: "km/h", kph: "km/h", "km/h": "km/h", knot: "kn", knots: "kn",
    "m²": "m2", sqm: "m2", "km²": "km2", "cm²": "cm2", "ft²": "ft2", sqft: "ft2", hectare: "ha",
    j: "J", joule: "J", kj: "kJ", wh: "Wh", kwh: "kWh", calorie: "cal",
    "°c": "C", c: "C", celsius: "C", "°f": "F", f: "F", fahrenheit: "F", k: "K", kelvin: "K"
};

function find(word) {
    var w = word.trim();
    var tries = [w, w.toLowerCase()];
    if (w.length > 2 && /s$/i.test(w))
        tries.push(w.slice(0, -1), w.slice(0, -1).toLowerCase());
    for (var i = 0; i < tries.length; i++) {
        var t = aliases.hasOwnProperty(tries[i]) ? aliases[tries[i]] : tries[i];
        if (t === "C" || t === "F" || t === "K")
            return { dim: "temperature", unit: t };
        for (var dim in units)
            if (units[dim].hasOwnProperty(t))
                return { dim: dim, unit: t };
    }
    return null;
}

function toKelvin(v, u) { return u === "K" ? v : u === "C" ? v + 273.15 : (v - 32) * 5 / 9 + 273.15; }
function fromKelvin(v, u) { return u === "K" ? v : u === "C" ? v - 273.15 : (v - 273.15) * 9 / 5 + 32; }

function format(v, digits) {
    var r = Number(v.toPrecision(digits));
    return Math.abs(r) >= 1e15 || (r !== 0 && Math.abs(r) < 1e-6) ? r.toExponential() : String(r);
}

// "5km" / "5 km": the amount, then the unit
function splitAmount(s) {
    var m = s.match(/^(.*?[\d)!.%])\s*([^\d\s()+\-*/^!%.,][^\d()+*^!%,]*)$/);
    return m ? { amount: m[1], unit: m[2] } : null;
}

// Returns { title, copy, subtitle } or null
function convert(query) {
    var m = query.trim().match(/^(.+?)\s+(?:to|in|as|into|->|=>|=)\s+(fl oz|\S+)$/i);
    if (!m)
        return null;
    var from = splitAmount(m[1].trim());
    if (!from)
        return null;
    var amount = Calc.run(from.amount.trim());
    if (!amount)
        return null;
    var v = amount.value;
    var target = m[2];

    var a = find(from.unit), b = find(target);
    if (a && b && a.dim === b.dim) {
        var out;
        if (a.dim === "temperature")
            out = fromKelvin(toKelvin(v, a.unit), b.unit);
        else
            out = v * units[a.dim][a.unit] / units[b.dim][b.unit];
        var label = b.dim === "temperature" ? "°" + b.unit : b.unit;
        if (b.unit === "K")
            label = "K";
        var text = format(out, 6);
        return { title: text + " " + label, copy: text, subtitle: format(v, 12) + " " + (a.dim === "temperature" && a.unit !== "K" ? "°" : "") + a.unit + " · ⏎ copy" };
    }

    return null;
}
