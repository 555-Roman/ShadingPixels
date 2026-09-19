#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 tangent;

/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 encodedTangent;
layout(location = 4) out vec4 normalTexture;
layout(location = 5) out vec4 specularTexture;

void main() {
    color = textureLod(gtexture, texcoord, 0.0) * glcolor;
    if (color.a < alphaTestRef) {
        discard;
    }
    color.rgb = pow(color.rgb, vec3(2.2));
    lightmapData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    encodedTangent = vec4(tangent * 0.5 + 0.5, 1.0);
    normalTexture = textureLod(normals, texcoord, 0.0);
    specularTexture = textureLod(specular, texcoord, 0.0);
    if (specularTexture.a == 0.0) specularTexture.a = 1.0;
}
