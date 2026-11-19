#version 440
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o Plate.frag.qsb Plate.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 first;
    vec2 second;
    vec2 third;
    vec3 rates;
    vec2 size;
    vec4 ink;
    vec4 paper;
};

void main() {
    vec2 dot_ = floor(qt_TexCoord0 * size);
    float a = length(dot_ - first), b = length(dot_ - second), c = length(dot_ - third);
    float wave = (sin(a * rates.x - time * 0.55) + sin(b * rates.y - time * 0.45) + sin(c * rates.z + time * 0.2)) / 3.0;
    vec2 from = (dot_ - vec2(size.x * 0.5, size.y * 0.49)) / vec2(size.x * 0.455, size.y * 0.345);
    float edge = clamp(1.0 - pow(abs(from.x), 6.0) - pow(abs(from.y), 6.0), 0.0, 1.0);
    float tone = pow(0.5 + 0.5 * wave, 1.6) * edge;
    if (min(a, b) < 1.6 || (c < 1.6 && third.y < size.y))
        tone = 1.0;
    float order = fract(dot(dot_, vec2(0.7548776662, 0.5698402910)));
    fragColor = (tone > order ? ink : paper) * qt_Opacity;
}
