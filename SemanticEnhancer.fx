#include "ReShadeUI.fxh"

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

uniform bool EnableSegmentationDebug
<
	ui_tooltip = "Enable segmentation debug!";
> = false;

uniform bool EnableLuminanceDebug
<
	ui_tooltip = "Enable Luminance debug!";
> = false;

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

texture FilteringTex {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT; 
	Format = RGBA32F;
};

sampler FilteringSampler {
	Texture = FilteringTex;
};

float4 SegmentationPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float lum = (GrayscaleWeights.r * color.r) + (GrayscaleWeights.g * color.g) + (GrayscaleWeights.b * color.b);
	
	if(lum >= RegionAStart && lum <= RegionAEnd) {
		return float4(RegionAColor, 1.0);
	}

	if(lum >= RegionBStart && lum <= RegionBEnd) {
		return float4(RegionBColor, 1.0);
	}
	
	return float4(color, 1.0f);
}	

float4 FilteringPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 region_id = tex2D(RegionIdSampler, texcoord).rgb;

	float offsets_x[8] = { -1.0f, 0.0f, 1.0f, -1.0f, 0.0f, 1.0f, -1.0f, 0.0f, 1.0f};
	float offsets_y[8] = { -1.0f,-1.0f, -1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f};
	float3 samples[8];

	for(int i = 0; i < 8; i++) {
		float offset_x = offsets_x[i] / BUFFER_WIDTH;
		float offset_y = offsets_y[i] / BUFFER_HEIGHT;
		samples[i] = tex2D(RegionIdSampler, texcoord + float2(offset_x, offset_y));
	}

	for(int i = 0; i < 8; i++) {

		
	}

	// Return color that appears most often in sample set

}	


float4 LuminancePass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 region_id = tex2D(FilteringSampler, texcoord).rgb;

	float original_lum = (GrayscaleWeights.r * color.r) + (GrayscaleWeights.g * color.g) + (GrayscaleWeights.b * color.b);
	float new_lum = lum;

	if(distance(region_id, RegionAColor) < 0.0001) {
		new_lum = float4(RegionALumScale * original_lum, 1.0);
	}

	if(distance(region_id, RegionBColor) < 0.0001) {
		new_lum = float4(RegionBLumScale * original_lum, 1.0);
	}

	return float4(new_lum, new_lum, new_lum, 1.0f);
}

float4 TransformationPass(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{
	float3 region_id = tex2D(RegionIdSampler, texcoord).rgb;
	float3 filtered_lum = tex2D(FilteringTex, texcoord).rgb;

	if(EnableSegmentationDebug) {
		return float4(region_id, 1.0f);
	}

	if(EnableLuminanceDebug) {
		return float4(filtered_lum, 1.0f);
	}

	return float4(color, 1.0f);
}

technique SemanticEnhancer
{
	pass SegmentationPass
	{
		VertexShader = PostProcessVS;
		PixelShader = SegmentationPass;
		RenderTarget = RegionIdTex;
	}

	pass FilteringPass
	{
		VertexShader = PostProcessVS;
		PixelShader = FilteringPass;
		RenderTarget = FilteringTex;
	}
	
	pass LuminancePass
	{
		VertexShader = PostProcessVS;
		PixelShader = LuminancePass;
		RenderTarget = LuminanceTex;
	}

	pass TransformationPass
	{
		VertexShader = PostProcessVS;
		PixelShader = TransformationPass;
	}
}

