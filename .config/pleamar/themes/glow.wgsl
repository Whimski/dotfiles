// glow — soft colour blobs behind a card, so only their edges glow out past
// it (the dark "aurora" look): pink towards the top right, warm orange beside
// it, blue towards the bottom left. Drawn before the card. The blobs drift and
// breathe slowly — only while the card is on screen; hidden, the clock stops.
// values: a.x = how far past the card it reaches (px), a.y = strength (0..1)
// colors: color = the top-right blob, color2 = the bottom-left one

fn blob(p: vec2<f32>, at: vec2<f32>, r: f32) -> f32 {
    let d = length(p - at) / r;
    return exp(-d * d);
}

fn shade(s: Shader) -> vec4<f32> {
    let m = max(1.0, s.a.x);
    let k = clamp(s.a.y, 0.0, 1.0);
    let inner = s.size - vec2<f32>(2.0 * m, 2.0 * m);     // the card itself
    let r = clamp(min(inner.x, inner.y) * 0.32, 24.0, 150.0);

    // each blob sits on an edge of the card, so half of it peeks out, and
    // wanders a little round there
    let t = s.time;
    let drift = r * 0.22;
    let pink = blob(s.pos, vec2<f32>(m + inner.x * 0.9 + sin(t * 0.31) * drift, m + inner.y * 0.08 + cos(t * 0.23) * drift), r * (1.0 + 0.12 * sin(t * 0.5)));
    let warm = blob(s.pos, vec2<f32>(m + inner.x * 0.62 + sin(t * 0.19 + 1.7) * drift * 1.5, m + cos(t * 0.27) * drift * 0.6), r * 0.65);
    let blue = blob(s.pos, vec2<f32>(m + inner.x * 0.06 + cos(t * 0.21 + 0.6) * drift, m + inner.y * 0.9 + sin(t * 0.29 + 2.1) * drift), r * (0.85 + 0.1 * cos(t * 0.43)));

    let orange = vec3<f32>(1.0, 0.68, 0.4);
    let total = pink + warm + blue + 1e-4;
    let rgb = (s.color.rgb * pink + orange * warm + s.color2.rgb * blue) / total;

    // fade to nothing before the edge of the box: no hard rectangle
    let edge = min(min(s.pos.x, s.size.x - s.pos.x), min(s.pos.y, s.size.y - s.pos.y));
    let fade = smoothstep(0.0, m * 0.9, edge);

    let a = clamp((pink * 0.8 + warm * 0.55 + blue * 0.7) * k, 0.0, 0.8) * fade;
    return vec4<f32>(rgb, a);
}
