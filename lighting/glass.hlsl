#include "material.hlsl"
#include "ior.hlsl"
#include "specular.hlsl"
#include "fresnelReflection.hlsl"

#include "ior/2eta.hlsl"
#include "ior/2f0.hlsl"

#include "common/reflection.hlsl"
#include "common/specularAO.hlsl"
#include "common/envBRDFApprox.hlsl"

/*
original_author: Patricio Gonzalez Vivo
description: simple glass shading model
use: 
    - <vec4> glass(<Material> material) 
    
options:
    - SPECULAR_FNC: specularGaussian, specularBeckmann, specularCookTorrance (default), specularPhongRoughness, specularBlinnPhongRoughnes (default on mobile)
    - SCENE_BACK_SURFACE: 
    - LIGHT_POSITION: in GlslViewer is u_light
    - LIGHT_DIRECTION: 
    - LIGHT_COLOR in GlslViewer is u_lightColor
    - CAMERA_POSITION: in GlslViewer is u_camera
*/

#ifndef LIGHT_COLOR
#define LIGHT_COLOR     float3(1.0, 1.0, 1.0)
#endif

#ifndef IBL_LUMINANCE
#define IBL_LUMINANCE   1.0
#endif

#ifndef FNC_GLASS
#define FNC_GLASS

float4 glass(const Material _mat) {
    float3    V       = normalize(CAMERA_POSITION - _mat.position);   // View

    float3    N       = _mat.normal;                                  // Normal front
    float3    No      = _mat.normal;                                  // Normal out

#if defined(SCENE_BACK_SURFACE)
              No      = normalize( N - _mat.normal_back );
#endif

    float roughness = _mat.roughness;

    float3    f0      = ior2f0(_mat.ior);
    float3    eta     = ior2eta(_mat.ior);
    float3    Re      = reflection(V, N, roughness);
    float3    RaR     = refract(-V, No, eta.r);
    float3    RaG     = refract(-V, No, eta.g);
    float3    RaB     = refract(-V, No, eta.b);

    float   NoV     = dot(N, V);                                    // Normal . View

    // Global Ilumination ( mage Based Lighting )
    // ------------------------
    float3 E = envBRDFApprox(_mat.albedo.rgb, NoV, roughness);

    float3 Fr = float3(0.0, 0.0, 0.0);
    Fr = tonemapReinhard( envMap(Re, roughness) ) * E;
    Fr += fresnelReflection(Re, _mat.f0, NoV) * (1.0-roughness);

    float4 color  = float4(0.0, 0.0, 0.0, 1.0);
    color.rgb   = envMap(RaG, roughness);
    color.r     = envMap(RaR, roughness).r;
    color.b     = envMap(RaB, roughness).b;

    // color.rgb   *= exp( -_mat.thickness * 200.0);

    color.rgb   += Fr * IBL_LUMINANCE;

    #if defined(LIGHT_DIRECTION)
    color.rgb += LIGHT_COLOR * specular(normalize(LIGHT_DIRECTION), N, V, roughness) * _mat.shadow;
    #elif defined(LIGHT_POSITION)
    color.rgb += LIGHT_COLOR * specular(normalize(LIGHT_POSITION - position), N, V, roughness) * _mat.shadow;
    #endif

    return color;
}

#endif