#version 440
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Dither.frag.qsb Dither.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 ink;
    vec4 paper;
    vec4 signal;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 dot_ = floor(qt_TexCoord0 * size);
    vec4 seen = texture(source, (dot_ + 0.5) / size);
    float tone = dot(seen.rgb, vec3(0.2126, 0.7152, 0.0722));
    float order = fract(dot(dot_, vec2(0.7548776662, 0.5698402910)));
    vec4 color = tone > order ? ink : paper;
    if (seen.r - max(seen.g, seen.b) > 0.3)
        color = signal;
    fragColor = color * qt_Opacity;
}
