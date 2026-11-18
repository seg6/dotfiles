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
    vec2 at = dot_ / 46.0;
    float gust = noise(at + vec2(-time * 0.11, time * 0.03));
    float eddy = noise(at * 1.9 + vec2(-time * 0.17, 7.3));
    vec2 moved = vec2((gust - 0.5) * 10.0 + (eddy - 0.5) * 4.0, (eddy - 0.5) * 3.0);
    vec2 from = dot_ + floor(moved + 0.5);
    // Off one side comes back on the other, so the edges are not smeared.
    from = vec2(mod(from.x, size.x), clamp(from.y, 0.0, size.y - 1.0));
    fragColor = texture(source, (from + 0.5) / size) * qt_Opacity;
}
