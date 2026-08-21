using CPP.EFFECTS;
using UnityEngine;
using UnityEngine.Rendering; 
using UnityEngine.Rendering.Universal;
using VJ.Midi;

public class VolumeController : MonoBehaviour, MIDIUser
{
    [SerializeField] private Volume _globalVolume;

    private Cross _cross;
    private DistortionEffect _distortion;
    private OctreeGridEffect _octreeGrid;
    private MirrorEffect     _mirror;
    private BlockEffect      _block;
    private InverseEffect    _inverse;
    private DitherEffect     _dither;
    
    public InputType ditherActiveMidiInput;
    public InputType ditherRndMidiInput;
    public InputType ditherSliderMidiInput;
    public InputType octreeGridMidiInput;
    public InputType octreeRndMidiInput;
    public InputType octreeBorderMidiInput;
    public InputType distortMidiInput;
    public InputType distortSliderMidiInput;
    
    public InputType _mirrorMidiInput1;
    public InputType _mirrorMidiInput2;
    public InputType _mirrorMidiInput3;
    public InputType _mirrorMidiInput4;
    
    public InputType inverseMidiInput;
    public InputType blockNoiseMidiInput;
    public InputType crossMidiInput;

    void Awake()
    {
        if (_globalVolume == null)
            _globalVolume = FindObjectOfType<Volume>();

        // 先把 Profile 取出
        VolumeProfile profile = _globalVolume.profile;
        //
        // // 1️⃣ DistortionEffect
        // if (profile.TryGet(out _distortion))
        // {
        //     // 保證這個效果被啟用（= Inspector 左側的核取方塊）
        //     _distortion.active = true;
        //
        //     _distortion.factor.overrideState = true;
        //     _distortion.factor.value        = 0.25f;
        //     _distortion.speed.value         = 1.5f;
        // }
        //
        // // 2️⃣ MirrorEffect
        // if (profile.TryGet(out _mirror))
        // {
        //     _mirror.active  = true;
        //     _mirror.horizontal.overrideState = true;
        //     _mirror.horizontal.value         = true;
        //     _mirror.vertical.value           = true;
        //     _mirror.left.value           = true;
        //     _mirror.up.value           = true;
        // }

        profile.TryGet(out _cross);
        profile.TryGet(out _distortion);
        profile.TryGet(out _mirror);
        profile.TryGet(out _block);
        profile.TryGet(out _inverse);
        profile.TryGet(out _octreeGrid);
        profile.TryGet(out _dither);
    }

    // 給別的腳本或 UI 呼叫
    public void SetDistortionFactor(float f)
    {
        if (_distortion != null)
            _distortion.factor.value = Mathf.Clamp01(f);
    }

    public void ToggleMirror(bool horizontal, bool vertical)
    {
        if (_mirror == null) return;

        _mirror.horizontal.value = horizontal;
        _mirror.vertical.value   = vertical;
    }

    // 若你只想整個 Volume 淡入淡出，可直接改權重
    public void FadeVolume(float t)   // t = 0~1
    {
        _globalVolume.weight = Mathf.Clamp01(t);
    }

    public void OnReceiveNote(InputType type)
    {
        if (_mirror != null)
        {
            if(_mirrorMidiInput1 == type)
                _mirror.horizontal.value = !_mirror.horizontal.value;
            if(_mirrorMidiInput2 == type)
                _mirror.vertical.value = !_mirror.vertical.value;
            if(_mirrorMidiInput3 == type)
                _mirror.left.value = !_mirror.left.value;
            if(_mirrorMidiInput4 == type)
                _mirror.up.value = !_mirror.up.value;
        }

        if (_block != null)
        {
            if(blockNoiseMidiInput == type)
                _block.active = !_block.active;
        }

        if (_inverse != null)
        {
            if (inverseMidiInput == type)
            {
                _inverse.active = !_inverse.active;
            }
        }

        if (_cross != null)
        {
            if (crossMidiInput == type)
            {
                _cross.active = !_cross.active;
            }
        }

        if (_dither != null)
        {
            if (ditherActiveMidiInput == type)
            {
                _dither.active = !_dither.active;
            }
            if (ditherRndMidiInput == type && _dither.active)
            {
                _dither.monoFactor.value = Random.value;
                _dither.pixel.value = Random.Range(320, 900);
                _dither.maskCount.value = Random.Range(0, 4);
            }
        }
        
        if (_octreeGrid != null)
        {
            if (octreeBorderMidiInput == type)
            {
                _octreeGrid.borderShowRate.value = Random.Range(0f,1f);
            }
            if (octreeRndMidiInput == type)
            {
                _octreeGrid.borderColor.value = Random.ColorHSV(0,1,1,1,1,1);
                _octreeGrid.size.value = Random.Range(0.8f,1.5f);
                _octreeGrid.cellCount.value = Random.Range(0,4);
                _octreeGrid.zFactor2.value = Random.Range(-0.03f,-0.15f);
            }
        }
        
        if (_distortion != null)
        {
            if (distortMidiInput == type)
            {
                _distortion.active = !_distortion.active;
            }
        }
    }

    public void OnReceiveControl(InputType type, float value)
    {
        if (_distortion != null)
        {
            if (distortSliderMidiInput == type && _distortion.active)
            {
                _distortion.factor.value = value;
            }
        }
        if (_octreeGrid != null && _octreeGrid.active)
        {
            if (octreeGridMidiInput == type)
            {
                _octreeGrid.factor.value = value;
            }
        }
        if (_dither != null)
        {
            if (ditherSliderMidiInput == type && _dither.active)
            {
                _dither.factor.value = value;
            }
        }
    }
}