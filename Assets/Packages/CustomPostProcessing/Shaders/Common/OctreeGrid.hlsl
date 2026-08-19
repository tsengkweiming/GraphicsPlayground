#ifndef OCTREE_GRID_HLSL
#define OCTREE_GRID_HLSL

// The hierarchy is procedural: no node buffer is allocated. Every query recreates
// the same leaf from its position and the deterministic hash below.
#define GRID_MAX_LEVELS 8
#define GRID_EPSILON 1e-5

uint3 pcg3d(uint3 state)
{
    state = state * 1145141919u + 1919810u;
    state.x += state.y * state.z;
    state.y += state.z * state.x;
    state.z += state.x * state.y;
    state ^= state >> 16u;
    state.x += state.y * state.z;
    state.y += state.z * state.x;
    state.z += state.x * state.y;
    return state;
}

float3 hashPcg3d(float3 seed)
{
    const uint3 hash = pcg3d(asuint(seed));
    return (float3)hash * (1.0 / 4294967295.0);
}

struct SubdivResult
{
    float3 size;
    float3 cell;
    float3 hash;
    int depth;
};

// Returns the deterministic leaf containing position. A node becomes a leaf when
// hash.x is below stopThreshold, or when maxLevels has been reached.
SubdivResult subdivision(
    float3 position,
    float3 rootCellSize,
    int maxLevels,
    float stopThreshold)
{
    SubdivResult result;
    result.size = max(abs(rootCellSize), GRID_EPSILON);
    result.cell = 0.0;
    result.hash = 0.0;
    result.depth = 0;

    const int levelCount = clamp(maxLevels, 1, GRID_MAX_LEVELS);
    const float threshold = saturate(stopThreshold);

    [loop]
    for (int level = 0; level < GRID_MAX_LEVELS; ++level)
    {
        if (level >= levelCount)
            break;

        result.cell = (floor(position / result.size) + 0.5) * result.size;
        result.hash = hashPcg3d(result.cell);
        result.depth = level;

        if (level + 1 >= levelCount || result.hash.x < threshold)
            break;

        result.size *= 0.5;
    }

    return result;
}

struct GridResult
{
    SubdivResult leaf;
    float distanceToBoundary;
};

// Advances a ray to the exit face of its current procedural leaf. rayDirection
// need not be normalized. Zero direction components are handled without NaNs.
GridResult gridTraversal(
    float3 rayOrigin,
    float3 rayDirection,
    float3 rootCellSize,
    int maxLevels,
    float stopThreshold)
{
    GridResult result;
    result.leaf = subdivision(
        rayOrigin + rayDirection * GRID_EPSILON,
        rootCellSize,
        maxLevels,
        stopThreshold);

    const float3 absDirection = abs(rayDirection);
    const float3 directionSign = lerp(-1.0, 1.0, step(0.0, rayDirection));
    const float3 exitFace = result.leaf.cell
                          + 0.5 * result.leaf.size * directionSign;
    const float3 finiteDistance = max(
        (exitFace - rayOrigin) * directionSign,
        0.0) / max(absDirection, GRID_EPSILON);
    const float3 axisDistance = lerp(
        float3(1e20, 1e20, 1e20),
        finiteDistance,
        step(GRID_EPSILON, absDirection));

    result.distanceToBoundary = max(
        min(axisDistance.x, min(axisDistance.y, axisDistance.z)),
        GRID_EPSILON);
    return result;
}

#endif
