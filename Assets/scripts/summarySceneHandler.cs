
using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XCharts.Runtime;

public class summarySceneHandler : MonoBehaviour
{
    public LineChart lineChart;
    public string title;
    private ConcurrentQueue<System.Action> _actionQueue = new ConcurrentQueue<System.Action>();
    private float shutdownTimer = 5f;
    public TextMeshProUGUI ssCummulativeScoreTxt;
    public TextMeshProUGUI ppCummulativeScoreTxt;
    public TextMeshProUGUI DcCummulativeScoreTxt;
    public TextMeshProUGUI TWCummulativeScoreTxt;
    public TextMeshProUGUI TTCummulativeScoreTxt;
    public TextMeshProUGUI MCCummulativeScoreTxt;
    public TextMeshProUGUI ssCurrentScoreTxt;
    public TextMeshProUGUI ppCurrentScoreTxt;
    public TextMeshProUGUI DCCurrentScoreTxt;
    public TextMeshProUGUI TWCurrentScoreTxt;
    public TextMeshProUGUI TTCurrentScoreTxt;
    public TextMeshProUGUI MCCurrentScoreTxt;
    public GameObject SSstar;
    public GameObject PPstar;
    public GameObject DCstar;
    public GameObject TWstar;
    public GameObject TTstar;
    public GameObject MCstar;
    public GameObject TotalStar;
    public TextMeshProUGUI totalStarCount;
    public TextMeshProUGUI totalStarCountUntilYesterday;

    public void Start()
    {
        //debug mode
        //AppData.Instance.Initialize(SceneManager.GetActiveScene().name);

        // Inialize the logger
        AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        title = "Unlock your Potential through Play";
        updateScores();
        initializeChart();
       
    }
    void Update()
    {
        shutdownTimer -= Time.deltaTime;
        if (shutdownTimer <= 0) exit();
    }
   
    public void updateScores()
    {
        int[] scores, cuScore;
        // --- Score texts ---
        scores = MarsGameDefs.Spaceshooter.GetScores();
        cuScore = MarsGameDefs.Spaceshooter.GetCummulativeScores();
        ssCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        ssCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        scores = MarsGameDefs.PingPong.GetScores();
        cuScore = MarsGameDefs.PingPong.GetCummulativeScores();
        ppCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        ppCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        scores = MarsGameDefs.DiamondCatcher.GetScores();
        cuScore = MarsGameDefs.DiamondCatcher.GetCummulativeScores();
        DcCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        DCCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        scores = MarsGameDefs.TableWiping.GetScores();
        cuScore = MarsGameDefs.TableWiping.GetCummulativeScores();
        TWCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        TWCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        scores = MarsGameDefs.TukTuk.GetScores();
        cuScore = MarsGameDefs.TukTuk.GetCummulativeScores();
        TTCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        TTCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        scores = MarsGameDefs.MatchCatch.GetScores();
        cuScore = MarsGameDefs.MatchCatch.GetCummulativeScores();
        MCCummulativeScoreTxt.text = cuScore[1].ToString("D4");
        MCCurrentScoreTxt.text = $"{scores[1]:D3} / {scores[0]:D3}";

        // --- Stars per movement: count achievements, fill in order ---
        // ML movement: SpaceShooter (star 1) + MatchCatch (star 2)
        int mlStars = (MarsGameDefs.Spaceshooter.IsAchievedToday() ? 1 : 0)
                    + (MarsGameDefs.MatchCatch.IsAchievedToday() ? 1 : 0);
        SetMovementStars(SSstar, MCstar, mlStars);

        // AP movement: PingPong (star 1) + TukTuk (star 2)
        int apStars = (MarsGameDefs.PingPong.IsAchievedToday() ? 1 : 0)
                    + (MarsGameDefs.TukTuk.IsAchievedToday() ? 1 : 0);
        SetMovementStars(PPstar, TTstar, apStars);

        // MLAP movement: DiamondCatcher (star 1) + TableWiping (star 2)
        int mlapStars = (MarsGameDefs.DiamondCatcher.IsAchievedToday() ? 1 : 0)
                      + (MarsGameDefs.TableWiping.IsAchievedToday() ? 1 : 0);
        SetMovementStars(DCstar, TWstar, mlapStars);

        // --- Total stars today ---
        int totalToday = mlStars + apStars + mlapStars;
        totalStarCount.text = totalToday.ToString("D3");
        if (totalToday > 0) TotalStar.GetComponent<Image>().color = Color.white;

        // --- Cumulative stars until last played date (all games, up to yesterday) ---
        int[] starData = MarsGameDefs.Spaceshooter.GetStarsCount();
        totalStarCountUntilYesterday.text = starData[2].ToString("D3")+"-->";
    }

    private void SetMovementStars(GameObject star1, GameObject star2, int count)
    {
        Color dimColor = new Color32(0x27, 0x22, 0x22, 255);
        star1.GetComponent<Image>().color = count >= 1 ? Color.white : dimColor;
        star2.GetComponent<Image>().color = count >= 2 ? Color.white : dimColor;
    }
    // To load the data for a specific movement into the bar graph.
    public void selectedMovements(Button button)
    {
        title = button.gameObject.name.ToUpper();
        SessionDataHandler.SelectedMovement(button.gameObject.name.ToUpper());
        AppLogger.LogInfo($"Selected '{title}'.");
        UpdateChartData();
    }
    public void exit()
    {
        AgentSession.Instance.StopSessionNow();
        // neurodash.OnSessionEnd();

        if (AppData.isNRSBuilt)
        {
            try
            {
                string dirPath = "C:/DeviceSetups/Mars";
                string filePath = Path.Combine(dirPath, "mars_demo_done.txt");
                Directory.CreateDirectory(dirPath);
                File.WriteAllText(filePath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                AppLogger.LogInfo("Created marker file at: " + filePath);
                Application.Quit();
                #if UNITY_EDITOR
                UnityEditor.EditorApplication.isPlaying = false;
                #endif
            }
            catch (System.Exception ex)
            {
                Debug.LogError("Failed to create marker file: " + ex.Message);
            }
            return;
        }

        AppLogger.LogInfo("Disconnected from Mars. Switching to DataUploading.");
        SceneManager.LoadScene("DATAUPLOADING");
    }


    public void initializeChart()
    {
        SessionDataHandler.MovTimePerDay();
        lineChart = gameObject.GetComponent<LineChart>();
        if (lineChart == null)
        {
            lineChart = gameObject.AddComponent<LineChart>();
            lineChart.Init();
        }
        // Title
        var titleComp = lineChart.EnsureChartComponent<Title>();
        titleComp.show = true;
        titleComp.text = title;

        // Tooltip & Legend
        lineChart.EnsureChartComponent<Tooltip>().show = true;
        lineChart.EnsureChartComponent<Legend>().show = true;

        // Axes
        var xAxis = lineChart.EnsureChartComponent<XAxis>();
        var yAxis = lineChart.EnsureChartComponent<YAxis>();

        xAxis.show = true;
        yAxis.show = true;

        xAxis.type = Axis.AxisType.Category;
        yAxis.type = Axis.AxisType.Value;

        // Fixed Y-axis limit 0 - 100
        yAxis.min = 0;
        yAxis.max = 100;

        // Enable zoom
        var dataZoom = lineChart.EnsureChartComponent<DataZoom>();
        dataZoom.enable = true;
        dataZoom.supportInside = true;
        dataZoom.supportSlider = true;
        dataZoom.start = 0;
        dataZoom.end = 100;
        UpdateChartData();
    }

    public void UpdateChartData()
    {
        if (lineChart == null) return;

        AppLogger.LogInfo("Linechart is not null");

        lineChart.RemoveData();
        lineChart.EnsureChartComponent<Title>().text = title;
        AppLogger.LogInfo("linechart clearing unwanted data");

        lineChart.AddSerie<Line>();

        var xAxis = lineChart.GetChartComponent<XAxis>();
        xAxis.data.Clear();

        DateTime today = DateTime.Today;

        for (int i = 0; i < SessionDataHandler.dateData.Length; i++)
        {
            string dateStr = SessionDataHandler.dateData[i];
            // Parse date
            DateTime entryDate = DateTime.Parse(dateStr);
            // Always show labels in the formate of date/Month
            xAxis.data.Add(entryDate.ToString("dd/MM"));

            if (entryDate > today)
            {
                // Add empty value → line breaks here
                lineChart.AddData(0, null);
            }
            else
            {
                // Add actual data
                float value = SessionDataHandler.moveTimeData[i];
                lineChart.AddData(0, value);
            }
        }
        AppLogger.LogInfo("DataUpdated successfully");
        lineChart.RefreshAllComponent();
    }
    private void OnApplicationQuit()
    {
        Application.Quit();
    }
}
