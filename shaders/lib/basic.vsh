#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

in vec4 at_tangent;
in vec2 mc_midTexCoord;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 tangent;
out vec2 textureMinBounds;
out vec2 singleTexSize;
out vec3 tangentViewDir;

mat3 tbnNormalTangent(vec3 normal, vec3 tangent) {
    vec3 bitangent = cross(tangent, normal);
    return mat3(tangent, bitangent, normal);
}

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
    glcolor = gl_Color;
    normal = gl_NormalMatrix * gl_Normal;
    tangent = gl_NormalMatrix * normalize(at_tangent.xyz);
    mat3 TBN = tbnNormalTangent(normal, tangent);
    normal = mat3(gbufferModelViewInverse) * normal;
    tangent = mat3(gbufferModelViewInverse) * tangent;
    vec2 halfSize = abs(texcoord - mc_midTexCoord);
    textureMinBounds = mc_midTexCoord - halfSize;
    singleTexSize = halfSize * 2.0;
    vec3 fragPosView = (gl_ModelViewMatrix * gl_Vertex).xyz;
    tangentViewDir = normalize(-fragPosView) * TBN;
}
