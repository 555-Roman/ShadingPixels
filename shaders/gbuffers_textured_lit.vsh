#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

in vec4 at_tangent;
in vec2 mc_midTexCoord;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 tangent;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
    glcolor = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
    tangent = gl_NormalMatrix * normalize(at_tangent.xyz);
    normal = mat3(gbufferModelViewInverse) * normal;
    tangent = mat3(gbufferModelViewInverse) * tangent;
}
