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

uniform float GaussianBlurOffset < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.00; ui_max = 1.00;
	ui_tooltip = "Additional adjustment for the blur radius. Values less than 1.00 will reduce the radius.";
> = 1.00;

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
	float offset[18] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4661974725, 21.4627427973, 23.4592916956, 25.455844494, 27.4524015179, 29.4489630909, 31.445529535, 33.4421011704 };
	float weight[18] = { 0.033245, 0.0659162217, 0.0636705814, 0.0598194658, 0.0546642566, 0.0485871646, 0.0420045997, 0.0353207015, 0.0288880982, 0.0229808311, 0.0177815511, 0.013382297, 0.0097960001, 0.0069746748, 0.0048301008, 0.0032534598, 0.0021315311, 0.0013582974 };
	
	lum *= weight[0];
	
	[loop]
	for(int i = 1; i < 18; ++i)
	{
		lum += tex2D(LuminanceSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		lum += tex2D(LuminanceSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
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

