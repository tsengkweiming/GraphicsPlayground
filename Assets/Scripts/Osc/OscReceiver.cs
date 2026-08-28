using System;
using System.Collections.Generic;
using extOSC;
using extOSC.Core;
using UnityEngine;
using UnityEngine.Events;

[Serializable]
public class OscReceiverParam
{
    public bool IsActive;
    public int Port;
    public OscReceiverParam()
    {
        Port = 10003;
        IsActive = true;
    }
}

public interface IMessageLogger
{
    public void UpdateLog(string key, string content, int maxLines = 10){ }
}

public abstract class OscReceiver : MonoBehaviour
{
    [SerializeField] protected OSCReceiver _oscReceiver;
    [SerializeField] protected OscReceiverParam _param;
    private Dictionary<string, List<string>> _messageLogs = new();
    public Dictionary<string, List<string>> MessageLogs => _messageLogs;
    public OscReceiverParam Param { get => _param; set => _param = value; }

    protected virtual void OnReceivedMessage(OSCMessage message)
    {
        UpdateLog(message.Address, message.ToString());
    }
    protected virtual void Bind(string address, UnityAction<OSCMessage> callback)
    {
        _oscReceiver.Bind(address, callback);
        _messageLogs.TryAdd(address, new List<string>());
    }
    protected virtual void UnBindAll()
    {
        _oscReceiver.ClearBinds();
    }
    protected virtual void UnBind(IOSCBind bind)
    {
        _oscReceiver.Unbind(bind);
    }
    public virtual void SetParam(OscReceiverParam param)
    {
        _param = param;
        SetPort(param.Port);
    }
    protected void SetPort(int port)
    {
        _oscReceiver.LocalPort = port;
        _oscReceiver.Connect();
    }
    public void UpdateLog(string key, string content, int maxLines = 10)
    {
        var logMessages = _messageLogs[key];
        if (logMessages.Count >= maxLines)
            logMessages.RemoveRange(0, Mathf.Max(2, logMessages.Count - maxLines));
        logMessages.Add($"[ {content} ] {DateTime.Now}");
    }
}
