#ifndef OCTREEGRID_HLSL
#define OCTREEGRID_HLSL

int _CellCount;
float3 _CellSize;

uint3 pcg3d( uint3 s ) {
  s = s * 1145141919u + 1919810u;
  s.x += s.y * s.z;
  s.y += s.z * s.x;
  s.z += s.x * s.y;
  s ^= s >> 16;
  s.x += s.y * s.z;
  s.y += s.z * s.x;
  s.z += s.x * s.y;
  return s;
}

/**
 * pcg3d but float
 */
float3 pcg3df( float3 s ) {
    uint3 r = pcg3d( asuint( s ) );
    return float3( r ) / float( 0xffffffffu );
}

/**
 * A function to generate a vec2 on a unit circle
 * Can be used for many purposes
 */
float2 cis( float t ) {
    return float2( cos( t ), sin( t ) );
}

struct SubdivResult {
    float3 size;
    float3 cell;
    float3 hash;
};

/**
 * Return the grid cell information the given point belongs to.
 */
SubdivResult subdivision( float3 p ) {
    SubdivResult result;

    // the initial size of a cell, it randomly halves
    result.size = _CellSize;//float3( 0.5, 0.5, 0.5 );

    for ( int i = 0; i < _CellCount; i ++ ) {
        // where is the center of the cell?
        result.cell = ( floor( p / result.size ) + 0.5 ) * result.size;

        // calculate a random hash for each cell
        result.hash = pcg3df( result.cell );

        // should we subdiv more? (the condition uses the random hash)
        if ( i == 4 || result.hash.x < 0.5 ) {
          break; // no
        } else {
          result.size *= 0.5; // yeah, halve the size and do this again
        }
    }

    return result;
}

struct GridResult {
    SubdivResult subdiv;
    float d;
};

/**
 * Return the grid cell information the ray currently belongs to
 * and a distance to the boundary of the cell.
 */
GridResult gridTraversal( float3 ro, float3 rd ) {
    GridResult result;

    // get the info of the current grid cell
    // slightly pushing the ray position forward to see the next cell
    result.subdiv = subdivision( ro + rd * 1E-3 );

    // calculate the distance to the boundary
    // It's basically a backface only cube intersection
    // See the iq shader: https://www.shadertoy.com/view/ld23DV
    float3 src = -( ro - result.subdiv.cell ) / rd;
    float3 dst = abs( 0.5 * result.subdiv.size / rd );
    float3 bv = src + dst;
    result.d = min( min( bv.x, bv.y ), bv.z );

    return result;
}

#endif