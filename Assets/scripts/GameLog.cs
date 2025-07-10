using UnityEngine;
using System;
using System.IO;

public class GameLog : MonoBehaviour
{
    public static GameLog instance;
    GameObject Player, Target, Enemy;
    public static string dateTime;
    public static string date;
    public static string sessionNum;
    private PlayerScore Playerscore;
    string fileName;
    float time;

    void Start()
    {
        Playerscore = FindObjectOfType<PlayerScore>();
        //ResetGameData();
        //InitializeSessionDetails();
        //CreateLogFile();
        //gameData.StartDataLog(fileName);
    }

    private void ResetGameData()
    {
        if (gameData.playerScore != 0 || gameData.enemyScore != 0)
        {
            gameData.playerScore = 0;
            gameData.enemyScore = 0;
            gameData.events = 0;
        }
    }

    private void InitializeSessionDetails()
    {
        dateTime = DateTime.Now.ToString("Dyyyy-MM-ddTHH-mm-ss");
        date = DateTime.Now.ToString("yyyy-MM-dd");
        sessionNum = "Session" + AppData.currentSessionNumber;
    }

    private void CreateLogFile()
    {
        string dir = Path.Combine(DataManager.directoryPathSession, date, sessionNum);
        Directory.CreateDirectory(dir);

        //fileName = Path.Combine(dir, $"{AppData.selectedMovement}_{AppData.selectedGame}_{dateTime}.csv");
        AppData.trialDataFileLocation = fileName;

        File.Create(fileName).Dispose();
    }
    void Update()
    {
       
        //if (gameData.isLogging)
        //{ 
        //    gameData.LogData();
        //}
        time += Time.deltaTime;
    }
    

    public void OnDestroy()
    {
        gameData.StopLogging();
    }
}

