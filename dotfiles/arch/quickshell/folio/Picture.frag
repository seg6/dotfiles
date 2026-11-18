#version 440
// The picture at the foot of the page, with wind passing through it. Every dot
// stays a whole dot: each one is only fetched from a little way off, and how
// far changes slowly, from left to right.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Picture.frag.qsb Picture.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
    vec2 dot_ = floor(qt_TexCoord0 * size);
    // The sky is the upper part of the picture: wide, slow, and it drifts.
    vec2 high = dot_ / 70.0;
    float cloud = noise(high + vec2(-time * 0.05, time * 0.012));
    float billow = noise(high * 2.3 + vec2(-time * 0.08, 3.1));
    vec2 sky = vec2((cloud - 0.5) * 14.0, (billow - 0.5) * 5.0);
    // The field below is close: quick gusts run through it, mostly sideways.
    vec2 low = dot_ / vec2(34.0, 16.0);
    float gust = noise(low + vec2(-time * 0.42, time * 0.05));
    float ripple = noise(low * 2.7 + vec2(-time * 0.9, 9.7));
    vec2 field = vec2((gust - 0.5) * 9.0 + (ripple - 0.5) * 3.0, (ripple - 0.5) * 1.5);
    vec2 moved = mix(sky, field, smoothstep(0.76, 0.88, qt_TexCoord0.y));
    vec2 from = dot_ + floor(moved + 0.5);
    // Off one side comes back on the other, so the edges are not smeared.
    from = vec2(mod(from.x, size.x), clamp(from.y, 0.0, size.y - 1.0));
    fragColor = texture(source, (from + 0.5) / size) * qt_Opacity;
}
