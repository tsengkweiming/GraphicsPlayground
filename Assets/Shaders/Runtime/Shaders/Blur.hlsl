#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDE_BLUR
#define POSTEFFECT_GRAPH_HLSL_INCLUDE_BLUR

#ifdef BLUR_LOW
            static const int SampleCount = 4;
            static const float Offsets[4] = { -2.351564403533789, -0.46943377969837197, 1.409199877085212, 3 };
            static const float Weights[4] = { 0.20281755282997538, 0.4044856614512111, 0.32139335373196054, 0.07130343198685299 };
#elif BLUR_NORMAL
            static const int SampleCount = 6;
            static const float Offsets[6] = { -4.378621204796657, -2.431625915613778, -0.4862426846689485, 1.4588111840004858, 3.4048471718931532, 5 };
            static const float Weights[6] = { 0.09461172151436463, 0.20023097066826712, 0.2760751120037518, 0.24804559825032563, 0.14521459357563646, 0.035822003987654526 };
#elif BLUR_HIGH
            static const int SampleCount = 8;
            static const float Offsets[8] = { -6.400317149797591, -4.4305055426526785, -2.4612181104350137, -0.49222828273139496, 1.4767017588568079, 3.4458098836553415, 5.415332322090894, 7 };
            static const float Weights[8] = { 0.057675741328188125, 0.1130965670295305, 0.17359677602551388, 0.20858861531815848, 0.19620401492479278, 0.14447384508442518, 0.08327585190842782, 0.023088588380963393 };
#elif BLUR_VERYHIGH
            static const int SampleCount = 13;
            static const float Offsets[13] = { -11.420990335232771, -9.434557915309014, -7.448223675960468, -5.461967313484028, -3.475769408144678, -1.4896094314876247, 0.49653490850373405, 2.4826862657413393, 4.468862236297167, 6.4550869992703435, 8.441379804986935, 10.427760570612987, 12 };
            static const float Weights[13] = { 0.02227795554977223, 0.039709142591126616, 0.06339981920440566, 0.09067187018112358, 0.11615733693280916, 0.13329329367184328, 0.13701280367389812, 0.12615488322440882, 0.10404853734916197, 0.07686995946152407, 0.05087052038704602, 0.030155073797681196, 0.009378803975199374 };
#elif BLUR_ULTRA
            static const int SampleCount = 27;
            static const float Offsets[27] = { -25.455869405623496, -23.459314786453096, -21.46276411612668, -19.466217007852766, -17.469673077802685, -15.47313195660739, -13.476593304227174, -11.480056825732497, -9.483522280511306, -7.48698946659084, -5.490458139229543, -3.4939277769387465, -1.4973970151011173, 0.4991313157669355, 2.4956625915064614, 4.492192892831225, 6.48872363880876, 8.485255669740168, 10.481789324503971, 12.478324809560167, 14.47486234147455, 16.471402188229323, 18.46794466913464, 20.4644901409081, 22.461038981819442, 24.45759157838014, 26 };
            static const float Weights[27] = { 0.007177128494145424, 0.010078405805746603, 0.013765638680033103, 0.01828791678517069, 0.023631734397463827, 0.029702346212576856, 0.03631199508101511, 0.04317914235278233, 0.04994161530115365, 0.05618437598080789, 0.06147977449743447, 0.06543530348684544, 0.06774176162650551, 0.06821293419242858, 0.06680953953299092,0.06364683268174064, 0.05897643249143868, 0.0531549308679544, 0.04659858405988612, 0.039734383378001475, 0.03295527075193222, 0.02658567414857793, 0.020860968370000454, 0.015921532906791012, 0.01181948861197724, 0.008534456003890023, 0.0032718333007095393 };
#else
            static const int SampleCount = 4;
            static const float Offsets[4] = { -2.351564403533789, -0.46943377969837197, 1.409199877085212, 3 };
            static const float Weights[4] = { 0.20281755282997538, 0.4044856614512111, 0.32139335373196054, 0.07130343198685299 };
#endif

/**
 * \brief Apply blur to the texture.
 * \param tex The texture to apply blur.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param direction The direction of the blur.
 * \param sampleStep The step of the sample.
 */
float3 ApplyBlur(sampler2D tex, float2 uv, float2 texelSize, float2 direction, float sampleStep)
{
    float3 color = 0;
    [unroll]
    for (int i = 0; i < SampleCount; i++)
    {
        const float2 offset = direction * Offsets[i] * texelSize * sampleStep;
        color += tex2D(tex, uv + offset).rgb * Weights[i];
    }
    return color;
}

/**
 * \brief Apply blur to the texture.
 * \param tex The texture to apply blur.
 * \param samplerState The sampler state of the texture.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param direction The direction of the blur.
 * \param sampleStep The step of the sample.
 */
float3 ApplyBlur(Texture2D tex, SamplerState samplerState, float2 uv, float2 texelSize, float2 direction, float sampleStep)
{
    float3 color = 0;
    [unroll]
    for (int i = 0; i < SampleCount; i++)
    {
        const float2 offset = direction * Offsets[i] * texelSize * sampleStep;
        color += tex.Sample(samplerState, uv + offset).rgb * Weights[i];
    }
    return color;
}

/**
 * \brief Down sample to the texture.
 * \param tex The texture to down sample.
 * \param samplerState The sampler state of the texture.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param sampleStep The step of the sample.
 */
float3 DownSample(sampler2D tex, float2 uv, float2 texelSize, float sampleStep)
{
    float4 offset = texelSize.xyxy * float4(-1, -1, 1, 1) * sampleStep;
    float4 o = tex2D(tex, uv) * 4;
    o += tex2D(tex, uv + offset.xy);
    o += tex2D(tex, uv + offset.xw);
    o += tex2D(tex, uv + offset.zy);
    o += tex2D(tex, uv + offset.zw);
    return half4(o.rgb * 0.125, 1.0);
}

/**
 * \brief Down sample to the texture.
 * \param tex The texture to down sample.
 * \param samplerState The sampler state of the texture.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param sampleStep The step of the sample.
 */
float3 DownSample(Texture2D tex, SamplerState samplerState, float2 uv, float2 texelSize, float sampleStep)
{
    float4 offset = texelSize.xyxy * float4(-1, -1, 1, 1) * sampleStep;
    float4 o = tex.Sample(samplerState, uv) * 4;
    o += tex.Sample(samplerState, uv + offset.xy);
    o += tex.Sample(samplerState, uv + offset.xw);
    o += tex.Sample(samplerState, uv + offset.zy);
    o += tex.Sample(samplerState, uv + offset.zw);
    return half4(o.rgb * 0.125, 1.0);
}

/**
 * \brief Up sample to the texture.
 * \param tex The texture to up sample.
 * \param samplerState The sampler state of the texture.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param sampleStep The step of the sample.
 */
float3 UpSample(sampler2D tex, float2 uv, float2 texelSize, float sampleStep)
{
    float4 offset = texelSize.xyxy * float4(-1, -1, 1, 1) * sampleStep;
    float4 o = tex2D(tex, uv + float2(offset.x, 0));
    o += tex2D(tex, uv + float2(offset.z, 0));
    o += tex2D(tex, uv + float2(0, offset.y));
    o += tex2D(tex, uv + float2(0, offset.w));
    o += tex2D(tex, uv + offset.xy * 0.5) * 2;
    o += tex2D(tex, uv + offset.xw * 0.5) * 2;
    o += tex2D(tex, uv + offset.zy * 0.5) * 2;
    o += tex2D(tex, uv + offset.zw * 0.5) * 2;
    return half4(o.rgb * 0.083333333333333, 1.0);
}

/**
 * \brief Up sample to the texture.
 * \param tex The texture to up sample.
 * \param samplerState The sampler state of the texture.
 * \param uv The uv of the texture.
 * \param texelSize The size of the texel.
 * \param sampleStep The step of the sample.
 */
float3 UpSample(Texture2D tex, SamplerState samplerState, float2 uv, float2 texelSize, float sampleStep)
{
    float4 offset = texelSize.xyxy * float4(-1, -1, 1, 1) * sampleStep;
    float4 o = tex.Sample(samplerState, uv + float2(offset.x, 0));
    o += tex.Sample(samplerState, uv + float2(offset.z, 0));
    o += tex.Sample(samplerState, uv + float2(0, offset.y));
    o += tex.Sample(samplerState, uv + float2(0, offset.w));
    o += tex.Sample(samplerState, uv + offset.xy * 0.5) * 2;
    o += tex.Sample(samplerState, uv + offset.xw * 0.5) * 2;
    o += tex.Sample(samplerState, uv + offset.zy * 0.5) * 2;
    o += tex.Sample(samplerState, uv + offset.zw * 0.5) * 2;
    return half4(o.rgb * 0.083333333333333, 1.0);
}

#endif