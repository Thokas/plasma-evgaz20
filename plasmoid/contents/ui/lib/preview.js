.pragma library
/*
 * How a preset looks, for drawing it: every LED's color at a time t (s).
 * The software effects follow z20's own (animation() in z20: keep the two
 * alike); the keyboard's own effects run in its firmware, so they are drawn
 * after how they look, close but not exact. LEDs as z20 leds lists them
 * ({led, name, x, y, w, h}, x and y the key's center in keys).
 */

.import "presets.js" as Presets

// z20 animate's defaults: colors and cycle (ms) of each software effect.
var SOFTWARE = { aurora: [["00ff90", "00a0ff", "6020ff"], 10000], fire: [["ff0000", "ff6000", "ffc000"], 800],
                 rain: [["00ff40", "c0ffc0"], 1500], ripple: [["00c0ff", "ff00c0", "ffc000"], 2500],
                 scanner: [["ff0000"], 2000], gradient: [["ff0080", "8000ff", "0080ff"], 0] };

function rgb(hex) {
    var n = parseInt(hex, 16);
    return [n >> 16 & 255, n >> 8 & 255, n & 255];
}

function hex(c) {
    return "#" + c.map(function (v) {
        return ("0" + Math.min(Math.max(Math.round(v), 0), 255).toString(16)).slice(-2);
    }).join("");
}

function scaled(c, k) {
    return [c[0] * k, c[1] * k, c[2] * k];
}

function mix(a, b, k) {
    return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
}

// The color at t (0-1) along colors, mixed between the two nearest; cyclic: the last blends back into
// the first, and t wraps around (z20's blend()).
function blend(colors, t, cyclic) {
    var n = colors.length;
    if (n === 1) {
        return colors[0];
    }
    if (cyclic) {
        var f = (t % 1 + 1) % 1 * n;
        return mix(colors[Math.floor(f) % n], colors[(Math.floor(f) + 1) % n], f - Math.floor(f));
    }
    var g = Math.min(Math.max(t, 0), 1) * (n - 1);
    var i = Math.min(Math.floor(g), n - 2);
    return mix(colors[i], colors[i + 1], g - i);
}

// A number in 0-1 that stays the same for the same n (a hash), for what looks random but holds still.
function noise(n) {
    var s = Math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return s - Math.floor(s);
}

function hue(h) {
    var k = function (n) { return Math.max(0, Math.min(1, Math.abs((n + h * 6) % 6 - 3) - 1)) * 255; };
    return [k(0), k(4), k(2)];
}

/*
 * The preset as {still, at(t)}: at(t) gives [r, g, b] (0-255) for each LED in leds, in their order;
 * still: the same for every t (drawn once). at() of fire, rain, ripple and reactive keeps state, so the
 * times have to come in order.
 */
function renderer(preset, leds) {
    var effect = preset ? preset.effect : "off";
    var software = SOFTWARE[effect];
    var given = (preset && preset.colors || []).map(rgb);
    var colors = given.length ? given : software ? software[0].map(rgb) : Presets.RAINBOW.map(rgb);
    var cycleMs = preset && preset.cycle || (software ? software[1] : 3000);
    var cycle = cycleMs / 1000;
    var level = preset && preset.brightness !== undefined ? preset.brightness / 100 : 1;
    var xs = leds.map(function (l) { return l.x; }), ys = leds.map(function (l) { return l.y; });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs);
    var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
    var each = function (f) {
        return function (t) {
            return leds.map(function (l, i) { return scaled(f(l, t, i), level); });
        };
    };
    var still = function (f) {
        return { still: true, at: each(f) };
    };
    var moving = function (f) {
        return { still: false, at: each(f) };
    };
    var black = [0, 0, 0];

    switch (effect) {
    case "off":
        return { still: true, at: each(function () { return black; }) };
    case "static":
        return still(function () { return colors[0]; });
    case "breathing":  // the first color in and out, then the second (dark: a pause)
        var second = colors[1] || black;
        return moving(function (l, t) {
            var u = (t / cycle) % 2;
            return scaled(u < 1 ? colors[0] : second, Math.sin(Math.PI * (u % 1)));
        });
    case "pulse":  // the whole keyboard flashes in one color after the other
        return moving(function (l, t) {
            var u = t / cycle;
            return scaled(colors[Math.floor(u) % colors.length], Math.pow(Math.sin(Math.PI * (u % 1)), 2));
        });
    case "spiral":  // the colors turning around the middle
        var turn = preset.direction === "ccw" ? 1 : -1;
        return moving(function (l, t) {
            var a = Math.atan2(l.y - (y0 + y1) / 2, (l.x - (x0 + x1) / 2) / 2);
            return blend(colors, a / (2 * Math.PI) + turn * t / cycle, true);
        });
    case "wave":  // the colors running across the keyboard
        var dir = preset.direction || "right";
        return moving(function (l, t) {
            var along = dir === "right" || dir === "left" ? (l.x - x0) / (x1 - x0) : (l.y - y0) / (y1 - y0);
            return blend(colors, along + (dir === "right" || dir === "down" ? -1 : 1) * t / cycle, true);
        });
    case "stars":  // keys lighting up here and there, each in its own color
        return moving(function (l, t, i) {
            var k = Math.max(0, Math.sin(2 * Math.PI * (t / cycle + noise(i))));
            return scaled(hue(noise(i + 0.5)), Math.pow(k, 8));
        });
    case "reactive":  // a pressed key lights up and fades: here keys pressed now and then
        var lit = [];
        var keys = leds.filter(function (l) { return l.led < 160; });
        var next = 0, count = 0;
        var fade = Math.max(cycle * 2, 0.4);
        return { still: false, at: function (t) {
            if (next > t + 1) {
                next = t;
            }
            while (next <= t) {
                lit.push([keys[Math.floor(Math.random() * keys.length)].led, next, colors[count++ % colors.length]]);
                next += 0.25 + Math.random() * 0.35;
            }
            lit = lit.filter(function (p) { return t - p[1] < fade; });
            return leds.map(function (l) {
                var c = black;
                lit.forEach(function (p) {
                    if (p[0] === l.led) {
                        c = scaled(p[2], 1 - (t - p[1]) / fade);
                    }
                });
                return scaled(c, level);
            });
        } };
    case "rows":  // a color per row, from the top
        var rows = ys.map(function (y) { return Math.round(y * 2); })
            .filter(function (y, i, all) { return all.indexOf(y) === i; }).sort(function (a, b) { return a - b; });
        return still(function (l) { return colors[rows.indexOf(Math.round(l.y * 2)) % colors.length]; });
    case "fade":  // the color fading in and out
        return moving(function (l, t) { return scaled(colors[0], (1 - Math.cos(2 * Math.PI * t / 3)) / 2); });
    }
    return softwareRenderer(effect, colors, cycleMs ? cycle : null, leds, x0, x1, y0, y1, level);
}

// z20 animate's effects, as z20 works them out (its animation()).
function softwareRenderer(effect, colors, cycle, leds, x0, x1, y0, y1, level) {
    var each = function (f) {
        return function (t) {
            return leds.map(function (l) { return scaled(f(l, t), level); });
        };
    };
    if (effect === "gradient") {  // the colors from left to right; drifting with a cycle
        return { still: !cycle, at: each(function (l, t) {
            return blend(colors, (l.x - x0) / (x1 - x0) + (cycle ? t / cycle : 0), !!cycle);
        }) };
    }
    if (effect === "aurora") {  // soft color fields, flowing through all the colors
        return { still: false, at: function (t) {
            var s = 2 * Math.PI * t / cycle;
            var cx = (x0 + x1) / 2 + (x1 - x0) / 3 * Math.sin(s), cy = (y0 + y1) / 2 + (y1 - y0) / 2 * Math.cos(2 * s);
            return leds.map(function (l) {
                var a = Math.sin(l.x * 0.3 + s) + Math.sin(l.y * 0.8 - 2 * s) + Math.sin((l.x + l.y) * 0.2 + 3 * s)
                    + Math.sin(Math.hypot(l.x - cx, l.y - cy) * 0.5 - 2 * s);
                return scaled(blend(colors, a / 5 + t / cycle, true), level);
            });
        } };
    }
    if (effect === "scanner") {  // a light running from side to side and back
        return { still: false, at: function (t) {
            var at = x0 + (x1 - x0) * (1 - Math.cos(2 * Math.PI * t / cycle)) / 2;
            return leds.map(function (l) {
                return scaled(colors[0], Math.exp(-Math.pow((l.x - at) / 1.5, 2)) * level);
            });
        } };
    }
    if (effect === "fire") {  // flames rising from the bottom row, the colors from embers to tips
        var cols = Math.floor(x1 - x0) + 3, rows = Math.floor(y1 - y0) + 3;
        var grid = function () {
            var g = [];
            for (var r = 0; r < rows; r++) {
                g.push(new Array(cols).fill(0));
            }
            return g;
        };
        var heat = grid(), before = grid();
        var step = cycle / rows;
        var palette = [[0, 0, 0]].concat(colors);
        var last = 0;
        return { still: false, at: function (t) {
            if (t - last > 1) {
                last = t - step;
            }
            while (last + step <= t) {
                last += step;
                before = heat.map(function (row) { return row.slice(); });
                heat[rows - 1] = heat[rows - 1].map(function () { return Math.pow(Math.random(), 0.4); });
                for (var r = 0; r < rows - 1; r++) {
                    for (var c = 0; c < cols; c++) {
                        var below = heat[r + 1][Math.min(Math.max(c + Math.floor(Math.random() * 3) - 1, 0), cols - 1)];
                        heat[r][c] = Math.max(0, below - Math.random() * 3.2 / rows);
                    }
                }
            }
            var k = (t - last) / step;
            return leds.map(function (l) {
                var r = Math.round((l.y - y0) / (y1 - y0) * (rows - 2)), c = Math.round(l.x - x0) + 1;
                var h = before[r][c] + (heat[r][c] - before[r][c]) * k;
                return scaled(blend(palette, Math.pow(h, 1.3), false), level);
            });
        } };
    }
    if (effect === "rain") {  // drops falling down each column with a fading trail
        var columns = Math.floor(x1 - x0) + 2, trail = 2.5;
        var speed = (y1 - y0 + trail) / cycle;
        var drops = [], speeds = [];
        for (var i = 0; i < columns; i++) {
            drops.push(y0 - Math.random() * 2 * (y1 - y0 + trail));
            speeds.push(speed * (0.7 + 0.6 * Math.random()));
        }
        var head = colors[1] || colors[0];
        var then = null;
        return { still: false, at: function (t) {
            var dt = then === null ? 0 : Math.min(t - then, 1);
            then = t;
            for (var c = 0; c < columns; c++) {
                drops[c] += speeds[c] * dt;
                if (drops[c] - trail > y1 + 0.5) {
                    drops[c] = y0 - 0.5 - Math.random() * (y1 - y0) / 2;
                    speeds[c] = speed * (0.7 + 0.6 * Math.random());
                }
            }
            return leds.map(function (l) {
                var d = drops[Math.round(l.x - x0)] - l.y;
                var c = d >= -0.5 && d < 0.5 ? head : d >= 0.5 && d < trail
                    ? scaled(colors[0], 1 - (d - 0.5) / (trail - 0.5)) : [0, 0, 0];
                return scaled(c, level);
            });
        } };
    }
    if (effect === "ripple") {  // rings spreading from random keys, one color after another
        var spots = leds.filter(function (l) { return l.led < 160; });
        var ripples = [], due = 0, count = 0;
        return { still: false, at: function (t) {
            if (due < t - cycle) {
                due = t;
            }
            while (due <= t) {
                var s = spots[Math.floor(Math.random() * spots.length)];
                ripples.push([s.x, s.y, due, colors[count++ % colors.length]]);
                due += cycle / 4 * (0.5 + Math.random());
            }
            ripples = ripples.filter(function (r) { return t - r[2] < cycle; });
            return leds.map(function (l) {
                var m = [0, 0, 0];
                ripples.forEach(function (r) {
                    var age = (t - r[2]) / cycle;
                    var k = Math.exp(-Math.pow((Math.hypot(l.x - r[0], l.y - r[1]) - age * 10) / 1.5, 2)) * (1 - age);
                    m = [m[0] + r[3][0] * k, m[1] + r[3][1] * k, m[2] + r[3][2] * k];
                });
                return scaled([Math.min(m[0], 255), Math.min(m[1], 255), Math.min(m[2], 255)], level);
            });
        } };
    }
    return { still: true, at: each(function () { return [0, 0, 0]; }) };
}
