#ifndef POSTEFFECT_GRAPH_HLSL_INCLUDE_COMMON
#define POSTEFFECT_GRAPH_HLSL_INCLUDE_COMMON

float Remap(float origFrom, float origTo, float targetFrom, float targetTo, float value)
{
    return lerp(targetFrom, targetTo, (value - origFrom) / (origTo - origFrom));
}

#endif
