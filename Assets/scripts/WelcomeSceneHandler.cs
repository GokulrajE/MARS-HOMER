using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using System.Threading.Tasks;
using System.Data;
using System.IO;
using System.Linq;

public class welcomeSceneHandler : MonoBehaviour
{
    //public GameObject loading;
    public TextMeshProUGUI userName;
    public TextMeshProUGUI timeRemainingToday;
    public TextMeshProUGUI todaysDay;
    public TextMeshProUGUI todaysDate;
    public TextMeshProUGUI versionText;
    public int daysPassed;
    public TextMeshProUGUI[] prevDays = new TextMeshProUGUI[7];
    public TextMeshProUGUI[] prevDates = new TextMeshProUGUI[7];
    public Image[] pies = new Image[7];
    public bool piChartUpdated = false;
    private DaySummary[] daySummaries;
    public static bool changeScene = false;
    public readonly string nextScene = "ROBOTCALIB";
    public bool attachMarsButtonEvent = false;

    private bool _uiReady = false;
    private const float RETRY_INTERVAL = 2f;
    private float _retryTimer = 0f;
    private bool _isConnecting = false;
    private bool _initCompleted = false;

    // Start is called before the first frame update
    void Start()
    {
        if (!Directory.Exists(Path.Combine(Application.dataPath, "data")) ||
            Directory.GetDirectories(DataManager.basePath).Length == 0)
        {
            SceneManager.LoadScene("CONFIG");
            return;
        }

        // Try to fully initialize (connects + loads userData).
        // If the device is off, Initialize() throws after the connection step.
        // userData will be null; Update() will complete it once the device connects.
        try
        {
            AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        }
        catch (Exception ex)
        {
            AppLogger.LogError($"Initialization failed (device not connected): {ex.Message}");
        }

        if (!File.Exists(DataManager.configFile))
        {
            SceneManager.LoadScene("CONFIG");
            return;
        }

        if (!Directory.Exists(DataManager.basePath))
            Directory.CreateDirectory(DataManager.basePath);

        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"'{SceneManager.GetActiveScene().name}' scene started.");
        versionText.text = "Version :" + Application.version;

        // Only update UI if userData was successfully loaded.
        if (AppData.Instance.userData != null)
            CompleteUISetup();
    }

    void CompleteUISetup()
    {
        daySummaries = AppData.Instance.userData.CalculateMoveTimePerDay();
        UpdateUserData();
        UpdatePieChart();
        _uiReady = true;
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();

        if (Input.GetKey(KeyCode.LeftControl) &&
           Input.GetKey(KeyCode.LeftShift) &&
           Input.GetKeyDown(KeyCode.X))
        {
            SceneManager.LoadScene("CONFIG");
        }

        // Once background Initialize() succeeds, complete the UI on the main thread.
        if (_initCompleted)
        {
            _initCompleted = false;
            if (AppData.Instance.userData != null)
                CompleteUISetup();
        }
        // Check if it time to switch to the next scene
        if (changeScene == true)
        {
            LoadTargetScene();
            changeScene = false;
        }
        // Retry Initialize() every RETRY_INTERVAL seconds on a background thread until
        // the device connects. Initialize() handles Connect, getVersion, startSensorStream,
        // and MarsUserData creation in one shot. AppLogger.StartLogging is guarded so
        // calling it again is safe.
        if (AppData.Instance.userData == null)
        {
            _retryTimer -= Time.deltaTime;
            if (_retryTimer <= 0f && !_isConnecting)
            {
                _retryTimer = RETRY_INTERVAL;
                _isConnecting = true;
                string scene = SceneManager.GetActiveScene().name;
                Debug.Log("retry");
                System.Threading.Tasks.Task.Run(() =>
                {
                    try
                    {
                        AppData.Instance.Initialize(scene);
                        _initCompleted = true;
                    }
                    catch { /* device still unavailable — will retry */ }
                    finally { _isConnecting = false; }
                });
            }
            return;
        }

        // Attach event listener for Mars button release
        if (!attachMarsButtonEvent && Time.timeSinceLevelLoad > 1&& !_initCompleted )
        {
            attachMarsButtonEvent = true;
            MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        }
      
    }

    public void OnMarsButtonReleased()
    {
        if (AppData.Instance.userData.isErrorOccurred())
        {
             AppLogger.LogError("Error Occured. Need to address it. check the error log file");
        }
        else
        {
            AppLogger.LogInfo("Mars button released.");
            changeScene = true;
        }
        
    }

    private void LoadTargetScene()
    {
        AppLogger.LogInfo($"Switching to the next scene '{nextScene}'.");
        SceneManager.LoadScene(nextScene);
    }

    private void UpdateUserData()
    {
        userName.text = AppData.Instance.userData.hospNumber;
        int movetime = AppData.Instance.userData.totalMoveTimeRemaining;
        if (AppData.Instance.userData.isExceeded)
        {
            timeRemainingToday.text = $"Done +{movetime}[min]";
            timeRemainingToday.color = Color.green;
           
        }
        else
        {
            timeRemainingToday.text = $"{movetime} min";
        }
        todaysDay.text = AppData.Instance.userData.getCurrentDayOfTraining().ToString();
        todaysDate.text = DateTime.Now.ToString("ddd, dd-MM-yyyy");
        if (!File.Exists(awsManager.filePathUploadStatus))
            awsManager.createFile(userName.text);
    }
    private void UpdatePieChart()
    {
        int N = daySummaries.Length;
        for (int i = 0; i < N; i++)
        {
            prevDays[i].text = daySummaries[i].Day;
            prevDates[i].text = daySummaries[i].Date;
            pies[i].fillAmount = daySummaries[i].MoveTime / AppData.Instance.userData.totalMoveTimePrsc;
            //pies[i].color = new Color32(148, 234, 107, 255);
        }
        piChartUpdated = true;
    }

    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
    // private void OnApplicationQuit()
    // {
    //     Application.Quit();
       
    // }
}
