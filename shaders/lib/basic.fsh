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
in vec2 textureMinBounds;
in vec2 singleTexSize;
in vec3 tangentViewDir;

/* RENDERTARGETS: 0,1,2,3,4,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 encodedTangent;
layout(location = 4) out vec4 normalTexture;
layout(location = 5) out vec4 specularTexture;

vec2 localToAtlas(vec2 texcoord) {
    vec2 localCoord = mod(texcoord, 1.0);

    return localCoord * singleTexSize + textureMinBounds;
}

vec2 atlasToLocal(vec2 texcoord) {
    return (texcoord - textureMinBounds) / singleTexSize;
}

float getHeight(vec2 texcoord) {
    vec2 texcoordAtlas = localToAtlas(texcoord);
    return 1.0 - textureLod(normals, texcoordAtlas, 0.0).a;
}

vec2 parallax(vec2 texcoord, vec3 viewDir) {
    float height = getHeight(texcoord);
    vec2 p = viewDir.xy / viewDir.z * (height * 0.25);
    return texcoord - p;
}

void main() {
    color = textureLod(gtexture, texcoord, 0.0) * glcolor;
    if (color.a < alphaTestRef) {
        discard;
    }
    color.rgb = pow(color.rgb, vec3(2.2));
    lightmapData = vec4(lmcoord, 0.0, 1.0);
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
    encodedTangent = vec4(tangent * 0.5 + 0.5, 1.0);

    vec2 samplingCoord = texcoord;

    samplingCoord = localToAtlas(parallax(atlasToLocal(texcoord), normalize(tangentViewDir)));

    color = textureLod(gtexture, samplingCoord, 0.0) * glcolor;
    color.rgb = pow(color.rgb, vec3(2.2));
    normalTexture = textureLod(normals, samplingCoord, 0.0);
    specularTexture = textureLod(specular, samplingCoord, 0.0);
    if (specularTexture.a == 0.0) specularTexture.a = 1.0;

//    color.rgb = vec3(textureLod(normals, samplingCoord, 0.0).r);
}
