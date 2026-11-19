#version 440
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Numeral.frag.qsb Numeral.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float clock;
    float reach;
    float stir;
    float burst;
    vec2 pointer;
    vec2 size;
    vec4 ink;
    vec4 paper;
};
layout(binding = 1) uniform sampler2D mask;

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
    vec2 off = dot_ - pointer;
    float far = length(off);
    vec2 out_ = far > 0.0 ? off / far : vec2(0.0);
    float push = exp(-far * far / 1400.0) * 20.0;
    float rings = sin(far * 0.5 - clock * 8.0) * exp(-far / 46.0) * 4.0 * stir;
    vec2 moved = dot_ - out_ * (push + rings) * reach;
    float loose = clamp(burst + reach * exp(-far * far / 2600.0) * 0.9, 0.0, 1.0);
    vec2 scatter = (vec2(hash(dot_ + 1.0), hash(dot_ + 9.0)) - 0.5) * 90.0 * loose * loose;
    bool inside = texture(mask, (moved + scatter + 0.5) / size).a > 0.5;

    vec2 q = moved / size.y;
    vec2 bend = vec2(fbm(q * 1.3 + vec2(0.0, time * 0.030)), fbm(q * 1.3 + vec2(5.2, -time * 0.024)));
    float body = fbm(q * vec2(1.1, 3.0) + 2.4 * bend + vec2(-time * 0.020, 0.0));
    float strands = fbm(q * vec2(2.6, 11.0) + 3.4 * bend + vec2(-time * 0.055, time * 0.01));
    float tone;
    if (inside) {
        tone = 0.20 + 0.85 * smoothstep(0.28, 0.66, body) * (0.55 + 0.75 * smoothstep(0.30, 0.70, strands));
    } else {
        float height = (dot_.y + 0.5) / size.y;
        tone = smoothstep(0.42, 0.74, body) * 0.08 * smoothstep(0.55, 0.98, height);
    }
    float order = fract(dot(dot_, vec2(0.7548776662, 0.5698402910)));
    fragColor = (tone > order ? ink : paper) * qt_Opacity;
}
