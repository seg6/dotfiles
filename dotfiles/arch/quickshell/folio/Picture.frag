#version 440
// The picture on the empty page: a valley drawn in dots, at the hour it is.
// The sun crosses by day and the moon by night, in its real phase. The slopes
// facing them are lit, stars come out, cloud drifts, the lake glints, and a
// window is lit after dark. Nothing here is a gray: every dot is ink or paper.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Picture.frag.qsb Picture.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    // How far the sun (or by night the moon) is across the sky, 0 to 1.
    float progress;
    // 1 in full day, 0 in full night, between at dawn and dusk.
    float light;
    // The moon: 0 new, 0.5 full.
    float phase;
    vec2 size;
    vec4 ink;
    vec4 paper;
};

const float PI = 3.14159265;
const float LAKE = 0.87;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float sum = 0.0, amp = 0.5;
    for (int i = 0; i < 4; i++) {
        sum += noise(p) * amp;
        p = p * 2.03 + 17.0;
        amp *= 0.5;
    }
    return sum;
}

// The 4x4 ordered dither: which dots come on first as a tone lightens.
float bayer2(vec2 p) {
    p = floor(p);
    return fract(p.x / 2.0 + p.y * p.y * 0.75);
}

float bayer(vec2 p) {
    return bayer2(0.5 * p) * 0.25 + bayer2(p) + 0.03125;
}

// The top of a range of hills at x, as a height down the page.
// A row of pointed tops of differing heights.
float peaks(float u) {
    return (1.0 - abs(fract(u) - 0.5) * 2.0) * (0.35 + 0.65 * hash(vec2(floor(u), 2.0)));
}

float ridge(float x, float base, float rise, float wide, float seed) {
    float u = x * wide + seed + noise(vec2(x * wide * 0.8 + seed, 6.0)) * 0.7;
    // Large tops carrying smaller ones.
    return base - rise * (peaks(u) * 0.64 + peaks(u * 2.3 + 0.3) * 0.26 + peaks(u * 5.7 + 0.6) * 0.10);
}

void main() {
    vec2 dot_ = floor(qt_TexCoord0 * size);
    vec2 p = (dot_ + 0.5) / size;
    float aspect = size.x / size.y;
    float dark = 1.0 - light;
    // Where the sun or moon stands. Its arc stays low, under the words.
    vec2 body = vec2(mix(0.10, 0.90, progress), 0.70 - sin(PI * progress) * 0.25);
    vec2 away = (p - body) * vec2(aspect, 1.0);
    float far = length(away);
    float radius = 0.034;
    // Low sun: dawn and dusk.
    float low = light * (1.0 - smoothstep(0.0, 0.22, sin(PI * progress)));

    // Sky.
    float tone = 0.0;
    // Stars, a few of them slowly going in and out.
    float star = hash(dot_ * 0.731 + 3.0);
    if (star > 0.9984 && p.y < 0.66) {
        float blink = step(0.25, fract(star * 733.0 + time * (0.03 + 0.05 * hash(dot_))));
        tone = max(tone, dark * blink * step(0.5, dark));
    }
    // A glow around a low sun.
    tone += low * exp(-far * 3.2) * 0.5;
    // Cloud, in a few long thin bars, moving off to the left.
    float cloud = fbm(vec2(p.x * 1.6 + time * 0.012, p.y * 34.0) + 40.0);
    float band = smoothstep(0.40, 0.50, p.y) * (1.0 - smoothstep(0.60, 0.68, p.y));
    tone += smoothstep(0.64, 0.68, cloud) * band * (0.22 + 0.22 * light + 0.3 * low);
    // The sun is a whole disc with rings of light round it; the moon shows its phase.
    if (light > 0.5) {
        tone += exp(-max(far - radius, 0.0) * 22.0) * 0.5;
        if (far < radius)
            tone = 1.0;
    } else if (far < radius) {
        float edge = sqrt(max(radius * radius - away.y * away.y, 0.0));
        float turn = cos(2.0 * PI * phase);
        bool lit = phase < 0.5 ? away.x > turn * edge : away.x < -turn * edge;
        tone = lit ? 1.0 : 0.16;
    } else {
        tone += exp(-(far - radius) * 30.0) * 0.22 * (1.0 - abs(cos(PI * phase)));
    }

    // Three ranges, far to near: a pale one in the haze, one with lit and
    // shadowed faces, and the dark shore with only its crest catching the light.
    float glow = mix(0.5, 1.0, light);
    for (int i = 0; i < 3; i++) {
        float base = i == 0 ? 0.76 : (i == 1 ? 0.82 : 0.875);
        float rise = i == 0 ? 0.34 : (i == 1 ? 0.24 : 0.06);
        float wide = i == 0 ? 2.3 : (i == 1 ? 3.4 : 5.0);
        float seed = i == 0 ? 3.0 : (i == 1 ? 19.0 : 41.0);
        float top = ridge(p.x, base, rise, wide, seed);
        if (p.y < top)
            continue;
        float step_ = 3.0 / size.x;
        // Shadows run down from each top at a slant, away from the light.
        float under = p.x + (p.y - top) * 0.55 * sign(body.x - p.x);
        float slope = (ridge(under + step_, base, rise, wide, seed) - ridge(under - step_, base, rise, wide, seed)) / (2.0 * step_);
        // Rising toward the light is the lit face.
        float facing = clamp(0.5 + slope * sign(body.x - p.x) * 2.5, 0.0, 1.0);
        float depth = (p.y - top) * size.y;
        float crest = (1.0 - step(1.0, depth)) * glow;
        if (i == 0)
            tone = mix(0.10, 0.24, facing) * glow;
        else if (i == 1)
            tone = mix(0.03, 0.50, facing) * mix(1.0, 0.35, smoothstep(0.0, 34.0, depth)) * glow + crest * facing * 0.5;
        else
            tone = crest * 0.5;
    }

    // The house on the near shore, dark against the hill, with a window lit after dark.
    vec2 house = vec2(floor(size.x * 0.705), floor(ridge(0.705, 0.875, 0.06, 5.0, 41.0) * size.y) + 1.0);
    vec2 at = dot_ - house;
    bool wall = at.x >= -4.0 && at.x <= 4.0 && at.y <= 0.0 && at.y >= -4.0;
    bool roof = at.y < -4.0 && at.y >= -9.0 && abs(at.x) <= 5.0 + (at.y + 4.0);
    if (wall || roof)
        tone = 0.0;
    if (roof && abs(at.x) == floor(5.0 + (at.y + 4.0)))
        tone = 0.55 * glow;
    if (at.x >= 1.0 && at.x <= 2.0 && at.y >= -3.0 && at.y <= -2.0)
        tone = dark > 0.5 ? 1.0 : 0.0;

    // The lake. It holds the light in a broken path, and the wind marks it.
    if (p.y > LAKE) {
        float down = (p.y - LAKE) / (1.0 - LAKE);
        float row = dot_.y;
        tone = 0.0;
        float lines = noise(vec2(p.x * 14.0 - time * 0.22 + hash(vec2(row, 1.0)) * 40.0, row * 0.9));
        tone += smoothstep(0.70, 0.78, lines) * (0.14 + 0.16 * light) * (0.4 + 0.6 * down);
        float spread = 0.012 + down * 0.07;
        float wobble = (noise(vec2(row * 0.7, time * 0.9)) - 0.5) * 0.03;
        float path = 1.0 - smoothstep(0.0, spread, abs(p.x - body.x + wobble));
        float broken = step(0.42, noise(vec2(p.x * 60.0 + time * 0.5, row * 1.3 + time * 0.6)));
        float strength = light > 0.5 ? 1.0 : (1.0 - abs(cos(PI * phase))) * 0.8;
        // Only what is above the hills can be seen in the water.
        strength *= smoothstep(0.74, 0.66, body.y);
        tone += path * broken * strength;
        // The window too.
        if (dark > 0.5 && abs(dot_.x - house.x - 1.5) < 1.0)
            tone += step(0.5, noise(vec2(row * 0.9, time * 1.2))) * (1.0 - smoothstep(0.0, 0.5, down));
    }

    float on = step(bayer(dot_), clamp(tone, 0.0, 1.0));
    fragColor = mix(paper, ink, on) * qt_Opacity;
}
