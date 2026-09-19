#version 330 compatibility

#include "lib/shadowFunctions.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
	vec4 homogeneousPos = projectionMatrix * vec4(position, 1.0);
	return homogeneousPos.xyz / homogeneousPos.w;
}

uniform vec3 shadowLightPosition;

uniform int worldTime;
uniform int moonPhase;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

/*
const int colortex0Format = RGB16;
*/

const float sunPathRotation = -30.0;
const int shadowMapResolution = 4096;
//const float shadowDistanceRenderMul = 1.0;
//const float shadowDistance = 128.0;

const vec3 blocklightColor = pow(vec3(0.7, 0.5, 0.2), vec3(2.2));
const vec3 ambientColor = pow(vec3(0.1), vec3(2.2));

const float timeSunriseBegin = 23215.0;
const float timeSunriseFull = 24000.0;
const float timeDay = 785.0;
const float timeSunsetBegin = 11215.0;
const float timeSunsetFull = 12000.0;
const float timeNightBegin = 12785.0;
const float timeNightFull = 14000.0;
const float timeNightDecrese = 22000.0;

const vec3 skylightColorSunrise = pow(vec3(0.3, 0.1, 0.0), vec3(2.2));
const vec3 skylightColorDay = pow(vec3(0.5, 0.6, 0.7), vec3(2.2));
const vec3 skylightColorSunset = pow(vec3(0.3, 0.1, 0.0), vec3(2.2));
const vec3 skylightColorNight = pow(vec3(0.1, 0.1, 0.2), vec3(2.2));

const vec3 sunlightColorSunrise = pow(vec3(0.7, 0.6, 0.4), vec3(2.2));
const vec3 sunlightColorDay = pow(vec3(1.5, 1.5, 1.3), vec3(2.2));
const vec3 sunlightColorSunset = pow(vec3(0.8, 0.6, 0.4), vec3(2.2));
const vec3 moonlightColorNight = pow(vec3(0.3, 0.3, 0.5), vec3(2.2));

const float moonPhaseMultiplier[8] = float[8](1.0, 0.75, 0.5, 0.25, 0.1, 0.25, 0.5, 0.75);
const float skylightPhaseMultiplier[8] = float[8](1.0, 0.8, 0.6, 0.4, 0.2, 0.4, 0.6, 0.8);

const vec3 hardcodedMetalN[8] = vec3[8](
	vec3(2.9114, 2.9497, 2.5845),		// Iron
	vec3(0.18299, 0.42108, 1.3734),		// Gold
	vec3(1.3456, 0.96521, 0.61722),		// Aluminum
	vec3(3.1071, 3.1812, 2.3230),		// Chrome
	vec3(0.27105, 0.67693, 1.3164),		// Copper
	vec3(1.9100, 1.8300, 1.4400),		// Lead
	vec3(2.3757, 2.0847, 1.8453),		// Platinum
	vec3(0.15943, 0.14512, 0.13547)		// Silver
);
const vec3 hardcodedMetalK[8] = vec3[8](
	vec3(3.0893, 2.9318, 2.7670),		// Iron
	vec3(3.4242, 2.3459, 1.7704),		// Gold
	vec3(7.4746, 6.3995, 5.3031),		// Aluminum
	vec3(3.3314, 3.3291, 3.1350),		// Chrome
	vec3(3.6092, 2.6248, 2.2921),		// Copper
	vec3(3.5100, 3.4000, 3.1800),		// Lead
	vec3(4.2655, 3.7153, 3.1365),		// Platinum
	vec3(3.9291, 3.1900, 2.3808)		// Silver
);

mat3 tbnNormalTangent(vec3 normal, vec3 tangent) {
	vec3 bitangent = cross(tangent, normal);
	return mat3(tangent, bitangent, normal);
}


vec3 schlickFresnel(vec3 F0, float cosTheta) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}
/* Sébastien Lagarde */
vec3 fresnelDielectric(float eta, float cosTheta) {
	float sinTheta2 = 1.0 - cosTheta * cosTheta;

	float t0 = sqrt(1.0 - (sinTheta2 / (eta * eta)));
	float t1 = eta * t0;
	float t2 = eta * cosTheta;

	float rs = (cosTheta - t1) / (cosTheta + t1);
	float rp = (t0 - t2) / (t0 + t2);

	return vec3(0.5 * (rs * rs + rp * rp));
}
vec3 fresnelConductor(vec3 eta, vec3 k, float cosTheta) {
	float cosTheta2 = cosTheta * cosTheta;
	float sinTheta2 = 1.0 - cosTheta2;
	vec3 eta2 = eta * eta;
	vec3 k2 = k * k;

	vec3 t0 = eta2 - k2 - sinTheta2;
	vec3 a2plusb2 = sqrt(t0 * t0 + 4.0 * eta2 * k2);
	vec3 t1 = a2plusb2 + cosTheta2;
	vec3 a = sqrt(0.5 * (a2plusb2 + t0));
	vec3 t2 = 2.0 * a * cosTheta;
	vec3 Rs = (t1 - t2) / (t1 + t2);

	vec3 t3 = cosTheta2 * a2plusb2 + sinTheta2 * sinTheta2;
	vec3 t4 = t2 * sinTheta2;
	vec3 Rp = Rs * (t3 - t4) / (t3 + t4);

	return 0.5 * (Rp + Rs);
}
/* Sébastien Lagarde */

float D_GGX(vec3 N, vec3 H, float a) {
	float a2     = a*a;
	float NdotH  = max(dot(N, H), 0.0);
	float NdotH2 = NdotH*NdotH;

	float nom    = a2;
	float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
	denom        = 3.1415926535 * denom * denom;

	return nom / denom;
}

float G1_GGX(float NdotV, float k) {
	float nom   = NdotV;
	float denom = NdotV * (1.0 - k) + k;

	return nom / denom;
}

float G_GGX(vec3 N, vec3 V, vec3 L, float a) {
	float k = (a + 1.0)*(a + 1.0) / 8.0;
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx1 = G1_GGX(NdotV, k);
	float ggx2 = G1_GGX(NdotL, k);

	return ggx1 * ggx2;
}

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		return;
	}

	vec2 lightmap = texture(colortex1, texcoord).rg;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 geoNormal = normalize((encodedNormal - 0.5) * 2.0);
	vec3 encodedTangent = texture(colortex3, texcoord).rgb;
	vec3 geoTangent = normalize((encodedTangent - 0.5) * 2.0);

	/* LABPBR */
	vec4 normalTexture = texture(colortex4, texcoord);

	vec3 texNormal = normalTexture.rgb * 2.0 - 1.0;
	texNormal.z = sqrt(1.0 - dot(texNormal.xy, texNormal.xy));
	mat3 tbn = tbnNormalTangent(geoNormal, geoTangent);
	vec3 normal = normalize(tbn * texNormal);

	float ambientOcclusion = normalTexture.b;


	vec4 specularTexture = texture(colortex5, texcoord);

	float perceptualSmoothness = specularTexture.r;
	float roughness = (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);
	roughness = max(roughness, 0.01);

	float dielectricF0 = specularTexture.g;
	int metalId = int(round(dielectricF0 * 255.0)) - 230;
	float metallic = float(metalId >= 0);

	float emission = specularTexture.a * 255.0 / 254.0;
	if (emission > 1.0) emission = 0.0;
	/* LABPBR */

	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	/* space conversion */
	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.z -= 0.001;
	shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
	vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
	/* space conversion */

	vec3 worldViewVector = mat3(gbufferModelViewInverse) * normalize(-viewPos);
	vec3 worldHalfwayVector = normalize(worldLightVector + worldViewVector);

	float cosThetaI = max(dot(normal, worldViewVector), 0.0);
	cosThetaI = dot(geoNormal, worldViewVector);
	vec3 F = vec3(0.0);
	if (metallic > 0.0) {
		if (metalId >= 8) {
			F = schlickFresnel(color.rgb, cosThetaI);
		} else {
			F = fresnelConductor(hardcodedMetalN[metalId], hardcodedMetalK[metalId], cosThetaI);
		}
	} else {
		float sqrtF0 = sqrt(dielectricF0);
		float ior = (1.0 + sqrtF0) / (1.0 - sqrtF0);
		F = fresnelDielectric(1.5, cosThetaI);
	}

	float alpha = roughness;
	float D = D_GGX(normal, worldHalfwayVector, alpha);
	float G = G_GGX(normal, worldViewVector, worldLightVector, alpha);

	vec3 diffuseLight = color.rgb / 3.1415926535 * (metallic > 0.0 ? 0.0 : 1.0);
	vec3 specularLight = D * F * G / (4.0 * dot(worldViewVector, normal) * dot(worldLightVector, normal));

	vec3 shadow = getShadow(shadowScreenPos);

	vec3 lightInfluence = (1.0 - F) * diffuseLight + max(specularLight, 0.0);
	lightInfluence *= max(dot(worldLightVector, normal), 0.0);
	lightInfluence *= dot(worldLightVector, geoNormal) > 0.0 ? 1.0 : 0.0;

	vec3 blocklight = pow(lightmap.r, 2.0) * blocklightColor * color.rgb;
	vec3 ambient = ambientColor * color.rgb * ambientOcclusion;
	vec3 emitted = color.rgb * emission;

	/* time dependant lighting */
	float time = float(worldTime);
	float multiplierSunrise = 0.0;
	float multiplierDay = 0.0;
	float multiplierSunset = 0.0;
	float multiplierNight = 0.0;
	// nothing -> full sunrise
	if (time >= timeSunriseBegin && time < timeSunriseFull) {
		multiplierSunrise = (time - timeSunriseBegin) / (timeSunriseFull - timeSunriseBegin);
	}
	// full sunrise -> full day
	if (time >= float(int(timeSunriseFull) % 24000) && time < timeDay) {
		multiplierSunrise = 1.0 - (time - float(int(timeSunriseFull) % 24000)) / (timeDay - float(int(timeSunriseFull) % 24000));
		multiplierDay = 1.0 - multiplierSunrise;
	}
	// full day
	if (time >= timeDay && time < timeSunsetBegin) {
		multiplierDay = 1.0;
	}
	// full day -> full sunset
	if (time >= timeSunsetBegin && time < timeSunsetFull) {
		multiplierDay = 1.0 - (time - timeSunsetBegin) / (timeSunsetFull - timeSunsetBegin);
		multiplierSunset = 1.0 - multiplierDay;
	}
	// full sunset -> nothing
	if (time >= timeSunsetFull && time < timeNightBegin) {
		multiplierSunset = 1.0 - (time - timeSunsetFull) / (timeNightBegin - timeSunsetFull);
	}
	// nothing -> full night
	if (time >= timeNightBegin && time < timeNightFull) {
		multiplierNight = (time - timeNightBegin) / (timeNightFull - timeNightBegin);
	}
	// full night
	if (time >= timeNightFull && time < timeNightDecrese) {
		multiplierNight = 1.0;
	}
	// full night -> nothing
	if (time >= timeNightDecrese && time < timeSunsetBegin) {
		multiplierNight = 1.0 - (time - timeNightDecrese) / (timeSunsetBegin - timeNightDecrese);
	}

	vec3 nightskylight = skylightPhaseMultiplier[moonPhase] * skylightColorNight;
	vec3 nightlight = moonPhaseMultiplier[moonPhase] * moonlightColorNight;
	/* time dependant lighting */


	vec3 skylightColor = skylightColorSunrise * multiplierSunrise +
						 skylightColorDay     * multiplierDay     +
						 skylightColorSunset  * multiplierSunset  +
						 nightskylight   * multiplierNight   ;
	vec3 skylight = lightmap.g * skylightColor * color.rgb;

	vec3 sunlightColor = sunlightColorSunrise * multiplierSunrise +
						 sunlightColorDay     * multiplierDay     +
						 sunlightColorSunset  * multiplierSunset  +
						 nightlight           * multiplierNight   ;
	vec3 sunlight = lightmap.g * sunlightColor * lightInfluence * shadow;

	color.rgb = blocklight + skylight + ambient + sunlight + emitted;
}
