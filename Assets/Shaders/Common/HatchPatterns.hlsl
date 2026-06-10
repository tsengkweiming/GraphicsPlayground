#ifndef CODEX_HATCH_PATTERNS_INCLUDED
#define CODEX_HATCH_PATTERNS_INCLUDED

#define HATCH_PATTERN_CROSS 0.0
#define HATCH_PATTERN_DIAGONAL 1.0
#define HATCH_PATTERN_VERTICAL_DIAGONAL 2.0
#define HATCH_PATTERN_DIAGONAL_CROSS 3.0
#define HATCH_PATTERN_HORIZONTAL_DIAGONAL 4.0

float2 HatchRotate2D(float2 pos, float radians)
{
    float s;
    float c;
    sincos(radians, s, c);
    return float2(c * pos.x - s * pos.y, s * pos.x + c * pos.y);
}

float3 HatchLinearToSRGB(float3 color)
{
    color = saturate(color);

#if defined(UNITY_COLORSPACE_GAMMA)
    return color;
#else
    float3 low = color * 12.92;
    float3 high = 1.055 * pow(max(color, 0.0), 1.0 / 2.4) - 0.055;
    return lerp(low, high, step(0.0031308, color));
#endif
}

float HatchSegmentDistance(float2 pos, float2 startPos, float2 endPos)
{
    float2 toPos = pos - startPos;
    float2 segment = endPos - startPos;
    float segmentLengthSq = max(dot(segment, segment), 0.00001);
    float projection = saturate(dot(toPos, segment) / segmentLengthSq);
    return length(toPos - segment * projection);
}

float HatchStrokeCoverage(float distanceToStroke, float strokeWidthCell, float softness)
{
    float halfWidth = max(strokeWidthCell * 0.5, 0.0001);
    float aa = max(fwidth(distanceToStroke) * max(softness, 0.0001), 0.0001);
    return 1.0 - smoothstep(halfWidth - aa, halfWidth + aa, distanceToStroke);
}

float HatchLineCoverage(float2 pos, float2 startPos, float2 endPos, float strokeWidthCell, float softness)
{
    float dist = HatchSegmentDistance(pos, startPos, endPos);
    return HatchStrokeCoverage(dist, strokeWidthCell, softness);
}

float HatchUnion(float a, float b)
{
    return saturate(a + b - a * b);
}

float HatchPatternMask(float2 localUv, float patternIndex, float strokeWidthCell, float softness)
{
    float vertical = HatchLineCoverage(localUv, float2(0.5, 0.0), float2(0.5, 1.0), strokeWidthCell, softness);
    float horizontal = HatchLineCoverage(localUv, float2(0.0, 0.5), float2(1.0, 0.5), strokeWidthCell, softness);
    float diagonalForward = HatchLineCoverage(localUv, float2(0.0, 0.0), float2(1.0, 1.0), strokeWidthCell, softness);
    float diagonalBack = HatchLineCoverage(localUv, float2(0.0, 1.0), float2(1.0, 0.0), strokeWidthCell, softness);

    float cross = HatchUnion(vertical, horizontal);
    float diagonal = diagonalBack;
    float verticalDiagonal = HatchUnion(vertical, diagonalBack);
    float diagonalCross = HatchUnion(diagonalForward, diagonalBack);
    float horizontalDiagonal = HatchUnion(horizontal, diagonalBack);

    float4 pattern = float4(patternIndex, patternIndex, patternIndex, patternIndex);
    float4 pick0123 = 1.0 - step(0.5, abs(pattern - float4(0.0, 1.0, 2.0, 3.0)));
    float pick4 = 1.0 - step(0.5, abs(patternIndex - 4.0));

    return saturate(dot(float4(cross, diagonal, verticalDiagonal, diagonalCross), pick0123)
        + horizontalDiagonal * pick4);
}

float HatchP5Brightness(float3 unityRgb, float brightnessLift)
{
    float3 p5Rgb = saturate(HatchLinearToSRGB(unityRgb) + brightnessLift);
    return max(max(p5Rgb.r, p5Rgb.g), p5Rgb.b);
}

float HatchQuantizeDarkness(float brightness, float divisions)
{
    float divs = clamp(floor(divisions + 0.5), 1.0, 4.0);
    float darkness = saturate(1.0 - brightness);
    return min(floor(darkness * divs), divs - 1.0);
}

float2 HatchGridFromColumns(float columns, float canvasAspect)
{
    float safeColumns = max(columns, 1.0);
    float safeAspect = max(canvasAspect, 0.0001);
    return float2(safeColumns, safeColumns / safeAspect);
}

float HatchStrokeWidthInCell(float strokeWeightPixels, float referenceWidth, float columns)
{
    float cellPixels = max(referenceWidth / max(columns, 1.0), 0.0001);
    return max(strokeWeightPixels / cellPixels, 0.0001);
}

float HatchCellIsValid(float2 cellId, float2 gridSize)
{
    float2 maxCell = gridSize - 0.0001;
    return step(0.0, cellId.x) * step(0.0, cellId.y)
        * step(cellId.x, maxCell.x) * step(cellId.y, maxCell.y);
}

float2 HatchCellCenterUv(float2 cellId, float2 gridSize)
{
    return (cellId + 0.5) / max(gridSize, 0.0001);
}

float3 HatchPaletteColor(
    float patternIndex,
    float3 color0,
    float3 color1,
    float3 color2,
    float3 color3)
{
    float4 pattern = float4(patternIndex, patternIndex, patternIndex, patternIndex);
    float4 pick = 1.0 - step(0.5, abs(pattern - float4(0.0, 1.0, 2.0, 3.0)));
    return color0 * pick.x + color1 * pick.y + color2 * pick.z + color3 * pick.w;
}

void HatchPatternMask_float(
    float2 localUv,
    float patternIndex,
    float strokeWidthCell,
    float softness,
    out float mask)
{
    mask = HatchPatternMask(localUv, patternIndex, strokeWidthCell, softness);
}

void HatchP5Quantize_float(
    float3 sourceColor,
    float brightnessLift,
    float divisions,
    out float patternIndex)
{
    float brightness = HatchP5Brightness(sourceColor, brightnessLift);
    patternIndex = HatchQuantizeDarkness(brightness, divisions);
}

void HatchPalette_float(
    float patternIndex,
    float3 color0,
    float3 color1,
    float3 color2,
    float3 color3,
    out float3 color)
{
    color = HatchPaletteColor(patternIndex, color0, color1, color2, color3);
}

#endif
