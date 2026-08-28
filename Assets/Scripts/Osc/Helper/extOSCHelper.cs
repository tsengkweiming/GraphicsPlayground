using extOSC;
using System;

public static class extOSCHelper
{
    public static object GetValueByType(OSCValue oscValue)
    {
        switch (oscValue.Type)
        {
            case OSCValueType.Long:
                return oscValue.LongValue;
            case OSCValueType.Char:
                return oscValue.CharValue;
            case OSCValueType.Color:
                return oscValue.ColorValue;
            case OSCValueType.Blob:
                return oscValue.BlobValue;
            case OSCValueType.Int:
                return oscValue.IntValue;
            case OSCValueType.True:
            case OSCValueType.False:
                return oscValue.BoolValue;
            case OSCValueType.Float:
                return oscValue.FloatValue;
            case OSCValueType.Double:
                return oscValue.DoubleValue;
            case OSCValueType.String:
                return oscValue.StringValue;
            case OSCValueType.Null:
                return null;
            case OSCValueType.Impulse:
                return null;
            case OSCValueType.TimeTag:
                return oscValue.TimeTagValue;
            case OSCValueType.Midi:
                return oscValue.MidiValue;
            case OSCValueType.Array:
                return oscValue.ArrayValue;
            default:
                throw new ArgumentOutOfRangeException(nameof(oscValue.Type), $"Unsupported OSC value type: {oscValue.Type}");
        }
    }
}