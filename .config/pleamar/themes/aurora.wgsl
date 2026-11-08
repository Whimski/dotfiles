// aurora — a soft light that drifts inside a card's background: two colour
// clouds that wander slowly and a faint third one between them. Faint, so
// what is written on the card stays easy to read. It moves only while the card
// is on screen; hidden, the clock stops.
// values: a.x = strength (0..1)
// colors: color = one cloud, color2 = the other

fn cloud(p: vec2<f32>, at: vec2<f32>, r: vec2<f32>) -> f32 {
    let d = (p - at) / r;
    return exp(-dot(d, d));
}

fn shade(s: Shader) -> vec4<f32> {
    let k = clamp(s.a.x, 0.0, 1.0);
    let t = s.time;
    let sz = s.size;
    let r = vec2<f32>(sz.x * 0.45, sz.y * 0.4);

    let a = cloud(s.pos, sz * vec2<f32>(0.78 + 0.12 * sin(t * 0.17), 0.18 + 0.1 * cos(t * 0.23)), r);
    let b = cloud(s.pos, sz * vec2<f32>(0.2 + 0.12 * cos(t * 0.13 + 1.0), 0.85 + 0.08 * sin(t * 0.19)), r * 1.1);
    let c = cloud(s.pos, sz * vec2<f32>(0.5 + 0.25 * sin(t * 0.11 + 2.0), 0.5 + 0.2 * cos(t * 0.15)), r * 0.8);

    let mid = mix(s.color.rgb, s.color2.rgb, 0.5) * vec3<f32>(1.0, 0.85, 0.75);
    let total = a + b + c * 0.6 + 1e-4;
    let rgb = (s.color.rgb * a + s.color2.rgb * b + mid * c * 0.6) / total;
    let alpha = clamp((a * 0.16 + b * 0.14 + c * 0.07) * k, 0.0, 0.22);
    return vec4<f32>(rgb, alpha);
}
