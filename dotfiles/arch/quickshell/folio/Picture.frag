#version 440
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Picture.frag.qsb Picture.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float clock;
    float light;
    float gale;
    float reach;
    float stir;
    vec2 pointer;
    vec2 size;
    vec4 ink;
    vec4 paper;
};

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
    return sum / 0.9375;
}

void main() {
    vec2 dot_ = floor(qt_TexCoord0 * size);
    float height = (dot_.y + 0.5) / size.y;
    vec2 off = dot_ - pointer;
    float far = length(off);
    vec2 out_ = far > 0.0 ? off / far : vec2(0.0);
    float push = exp(-far * far / 1100.0) * 18.0;
    float rings = sin(far * 0.5 - clock * 8.0) * exp(-far / 46.0) * 4.0 * stir;
    vec2 q = (dot_ - out_ * (push + rings) * reach) / size.y;

    vec2 bend = vec2(fbm(q * 1.3 + vec2(0.0, time * 0.030)), fbm(q * 1.3 + vec2(5.2, -time * 0.024)));
    float body = fbm(q * vec2(1.1, 3.0) + 2.4 * bend + vec2(-time * 0.020, 0.0));
    float strands = fbm(q * vec2(2.6, 11.0) + 3.4 * bend + vec2(-time * 0.055, time * 0.01));
    float tone = smoothstep(0.34, 0.72, body) * 0.80;
    tone *= 0.45 + 1.1 * smoothstep(0.30, 0.70, strands);
    float rise = smoothstep(0.40, 0.98, height + (bend.x - 0.5) * 0.22);
    tone *= rise * (0.35 + 0.95 * rise);
    tone *= mix(0.55, 1.0, light) * (1.0 + 0.22 * gale);
    tone *= 1.0 - exp(-far * far / 260.0) * reach * 0.85;

    float order = fract(dot(dot_, vec2(0.7548776662, 0.5698402910)));
    vec4 color = tone > order ? ink : paper;

    float dark = 1.0 - light;
    float star = hash(dot_ * 0.731 + 3.0);
    if (star > 0.9987 && height < 0.60) {
        float blink = step(0.22, fract(star * 733.0 + clock * (0.02 + 0.05 * hash(dot_))));
        if (blink * dark > 0.5)
            color = ink;
    }
    float turn = floor(clock / 37.0);
    float fall = (clock - turn * 37.0) / 0.9;
    if (dark > 0.5 && fall < 1.0) {
        vec2 start = vec2(hash(vec2(turn, 1.0)) * 0.7 + 0.15, hash(vec2(turn, 2.0)) * 0.22 + 0.06) * size;
        vec2 along = normalize(vec2(110.0, 38.0));
        vec2 rel = dot_ - (start + vec2(110.0, 38.0) * fall);
        float back = -dot(rel, along);
        if (back >= 0.0 && back < 26.0 * (1.0 - fall) + 3.0 && abs(dot(rel, vec2(-along.y, along.x))) < 0.6)
            color = ink;
    }
    fragColor = color * qt_Opacity;
}
