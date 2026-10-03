using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.SceneManagement;

public class AgentSession : MonoBehaviour
{
    private static AgentSession _instance;
    public static AgentSession Instance
    {
        get
        {
            if (_instance == null)
            {
                var go = new GameObject("[AgentSession]");
                _instance = go.AddComponent<AgentSession>();
                DontDestroyOnLoad(go);
            }
            return _instance;
        }
    }

    private const string BaseUrl = "http://127.0.0.1:5055";

    void Awake()
    {
        if (_instance != null && _instance != this) { Destroy(gameObject); return; }
        _instance = this;
        DontDestroyOnLoad(gameObject);
        Application.quitting += OnQuitting;
    }

    void OnDestroy()
    {
        Application.quitting -= OnQuitting;
    }

    // ── /start ───────────────────────────────────────────────────
    // Called from LoginHandler. Yields until a response arrives.
    // onResult(statusCode, body): 200 = ok, 409 = conflict, -1 = agent offline
    public IEnumerator CallStart(string patientId, System.Action<int, string> onResult)
    {
        string url = $"{BaseUrl}/start?patient={UnityWebRequest.EscapeURL(patientId)}";
        using (var req = UnityWebRequest.Get(url))
        {
            req.timeout = 5;
            yield return req.SendWebRequest();

            if (req.result == UnityWebRequest.Result.ConnectionError ||
                req.result == UnityWebRequest.Result.DataProcessingError)
            {
                onResult(-1, ""); // agent not running — caller proceeds without restriction
                yield break;
            }
            onResult((int)req.responseCode, req.downloadHandler?.text ?? "");
        }
    }

    // ── /trial-ended ─────────────────────────────────────────────
    // Called from AppData.StopTrial() after each trial.
    // Fire-and-forget: if the reply has 'lost' set, stop the session.
    public void NotifyTrialEnded()
    {
        StartCoroutine(CallTrialEnded());
    }

    IEnumerator CallTrialEnded()
    {
        using (var req = UnityWebRequest.Get($"{BaseUrl}/trial-ended"))
        {
            req.timeout = 5;
            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success || req.responseCode != 200)
                yield break;

            var json = SimpleJSON.JSON.Parse(req.downloadHandler.text);
            if (json == null) yield break;

            var lostNode = json["lost"];
            if (!lostNode.IsNull && lostNode.AsBool)
                Debug.LogWarning($"[AgentSession] trial-ended: session lost — {lostNode.Value}");
        }
    }

    // ── /stop ────────────────────────────────────────────────────
    // Called from summarySceneHandler.exit() on session end / logout.
    public void StopSession()
    {
        StartCoroutine(CallStop());
    }

    IEnumerator CallStop()
    {
        using (var req = UnityWebRequest.Get($"{BaseUrl}/stop"))
        {
            req.timeout = 3;
            yield return req.SendWebRequest();
        }
    }

    // Synchronous best-effort /stop — coroutines don't run during shutdown
    void OnQuitting()
    {
        try
        {
            using (var client = new System.Net.WebClient())
                client.DownloadString($"{BaseUrl}/stop");
        }
        catch { /* best effort — app is closing */ }
    }
}
