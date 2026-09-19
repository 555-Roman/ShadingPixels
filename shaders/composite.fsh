#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform vec3 sunPosition;
uniform vec3 playerLookVector;

uniform int worldTime;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
	vec4 homogeneousPos = projectionMatrix * vec4(position, 1.0);
	return homogeneousPos.xyz / homogeneousPos.w;
}

in vec2 texcoord;

const int noiseTextureResolution = 128;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 radialBlur(vec2 center, vec2 texcoord) {
	float blurStart = 0.1;
	float blurWidth = 1.0;
	const int nSamples = 256;

	texcoord -= center;
	float precompute = blurWidth * (1.0 / float(nSamples - 1.0));

	vec3 color = vec3(0.0);
	for (int i = 0; i < nSamples; i++) {
		float scale = blurStart + (float(i) * precompute);
		color += texture(depthtex0, texcoord * scale + center).r == 1.0 ? 1.0 : 0.0;
	}

	color /= float(nSamples);

	return color;
}

const float timeSunriseBegin = 23215.0;
const float timeSunriseFull = 24000.0;
const float timeDay = 785.0;
const float timeSunsetBegin = 11215.0;
const float timeSunsetFull = 12000.0;
const float timeNightBegin = 12785.0;
const float timeNightFull = 14000.0;
const float timeNightDecrese = 22000.0;

const vec3 sunlightColorSunrise = pow(vec3(0.7, 0.6, 0.4), vec3(2.2));
const vec3 sunlightColorDay = pow(vec3(1.5, 1.5, 1.3), vec3(2.2));
const vec3 sunlightColorSunset = pow(vec3(0.8, 0.6, 0.4), vec3(2.2));
const vec3 moonlightColorNight = pow(vec3(0.3, 0.3, 0.5), vec3(2.2));

void main() {
	color.rgb = texture(colortex0, texcoord).rgb;
	vec2 sunScreenPos = projectAndDivide(gbufferProjection, sunPosition).xy * 0.5 + 0.5;
	float cornerFading = pow(max(1.0 - length(sunScreenPos - .5), 0.0), 2.0);

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
	/* time dependant lighting */

	vec3 sunlightColor = sunlightColorSunrise * multiplierSunrise +
						 sunlightColorDay     * multiplierDay     +
						 sunlightColorSunset  * multiplierSunset  ;

	float timeFading = max(multiplierSunrise, multiplierSunset);

	if (dot(mat3(gbufferModelView) * playerLookVector, sunPosition) > 0.0 && (worldTime >= 23215 || worldTime < 12785))
		color.rgb += timeFading * cornerFading * sunlightColor * 0.2 * vec3(radialBlur(sunScreenPos, texcoord));
}