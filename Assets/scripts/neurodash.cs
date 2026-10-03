using System.Diagnostics;
using UnityEngine;

public static class neurodash
{
    private static Process activeProcess = null;

    public static bool isRunning => activeProcess != null && !activeProcess.HasExited;

    // Returns false if a process is already running (caller can check and skip)
    public static bool start()
    {
        if (isRunning) return false;
        activeProcess = RunSender("--login");
        return activeProcess != null;
    }

    public static void OnSessionEnd()
    {
        RunSender("--upload");
    }

    static Process RunSender(string mode)
    {
        ProcessStartInfo info = new ProcessStartInfo();
        info.FileName = "python";
        info.Arguments = $@"C:\sender.py {mode}";
        info.UseShellExecute = false;
        info.CreateNoWindow = true;
        try
        {
            return Process.Start(info);
        }
        catch (System.Exception e)
        {
            UnityEngine.Debug.LogWarning($"neurodash: failed to start sender ({mode}): {e.Message}");
            return null;
        }
    }
}
