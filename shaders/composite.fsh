#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

const int noiseTextureResolution = 128;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color.rgb = texture(colortex0, texcoord).rgb;
}