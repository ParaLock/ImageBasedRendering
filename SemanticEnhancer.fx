#include "ReShadeUI.fxh"

//GaussanBlur credit goes to: https://github.com/crosire/reshade-shaders/blob/master/Shaders/GaussianBlur.fx

uniform float3 GrayscaleWeights <
	ui_tooltip = "Grayscale rgb weights";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 20.00;
	ui_step = 0.01;
> = float3(0.3,0.59,0.11);

//---------- Region A Params ----------
uniform float3 RegionAColor <
	ui_tooltip = "Region A Id";
	ui_type = "color";
> = float3(0.0,0.0,0.0);

uniform float RegionAStart <
	ui_tooltip = "Region A Start Threshold";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 1.00;
	ui_step = 0.01;
> = float(0.0);

uniform float RegionAEnd <
	ui_tooltip = "Region A End Threshold";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 1.00;
	ui_step = 0.01;
> = float(0.0);

uniform float RegionALumScale <
	ui_tooltip = "Region A Lum Scale";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 100.00;
	ui_step = 0.001;
> = float(1.0);

//---------- Region A Params END ----------

//---------- Region A Params ----------
uniform float3 RegionBColor <
	ui_tooltip = "Region B Color";
	ui_type = "color";
> = float3(0.0,0.0,0.0);

uniform float RegionBStart <
	ui_tooltip = "Region B Start Threshold";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 1.00;
	ui_step = 0.01;
> = float(0.0);

uniform float RegionBEnd <
	ui_tooltip = "Region B End Threshold";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 1.00;
	ui_step = 0.01;
> = float(0.0);

uniform float RegionBLumScale <
	ui_tooltip = "Region B Lum Scale";
	ui_type = "slider";
	ui_min = 0.00; 
	ui_max = 100.00;
	ui_step = 0.001;
> = float(1.0);

//---------- Region A Params END ----------
uniform bool EnableLuminanceDebug
<
	ui_tooltip = "Enable Luminance debug!";
> = false;

uniform float GaussianBlurStrength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.00; ui_max = 1.00;
	ui_tooltip = "Adjusts the strength of blue.";
> = 0.300;

#include "ReShade.fxh"

texture RegionIdTex {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT; 
	Format = RGBA32F;
};

sampler RegionIdSampler {
	Texture = RegionIdTex;
};

texture LuminanceTex {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT; 
	Format = RGBA32F;
};

sampler LuminanceSampler {
	Texture = LuminanceTex;
};


float4 SegmentationPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float lum = (GrayscaleWeights.r * color.r) + (GrayscaleWeights.g * color.g) + (GrayscaleWeights.b * color.b);
	float new_lum;
	
	if(lum >= RegionAStart && lum <= RegionAEnd) {
		new_lum = RegionALumScale;
	}

	if(lum >= RegionBStart && lum <= RegionBEnd) {
		new_lum = RegionBLumScale;
	}

	return float4(new_lum, new_lum, new_lum, 1.0f);
}	

float4 FilteringPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 orig_lum = tex2D(LuminanceSampler, texcoord).rgb;
	float3 lum = tex2D(LuminanceSampler, texcoord).rgb;
	float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
	float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
	
	lum *= weight[0];
	
	[loop]
	for(int i = 1; i < 4; ++i)
	{
		lum += tex2D(LuminanceSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y)).rgb * weight[i];
		lum += tex2D(LuminanceSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y)).rgb * weight[i];
	}

	lum = lerp(orig_lum, lum, GaussianBlurStrength);

	return float4(lum, 1.0f);
}

float4 TransformationPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 lum = tex2D(LuminanceSampler, texcoord).rgb;

	if(EnableLuminanceDebug) {
		return float4(lum, 1.0f);
	}

	return float4(color * lum, 1.0f);
}

technique SemanticEnhancer
{
	pass SegmentationPass
	{
		VertexShader = PostProcessVS;
		PixelShader = SegmentationPass;
		RenderTarget = LuminanceTex;
	}

	pass FilteringPass
	{
		VertexShader = PostProcessVS;
		PixelShader = FilteringPass;
		RenderTarget = LuminanceTex;
	}

	pass TransformationPass
	{
		VertexShader = PostProcessVS;
		PixelShader = TransformationPass;
	}
}

