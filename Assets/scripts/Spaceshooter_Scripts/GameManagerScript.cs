using NeuroRehabLibrary;
using System.Collections;
using System.Collections.Generic;
using System.Data.Common;
using System.IO;
using TMPro;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class GameManagerScript : MonoBehaviour
{
    private GameSession currentGameSession;
    public GameObject GameOverPanel;
    public Image SupportSlider;
    public TextMeshProUGUI support;
    public TextMeshProUGUI timerText;
    public TextMeshProUGUI angeltext;
    public bool Levelunlocked = false;
    public bool isGameOver = false; // Tracks the game over state
    public float gameDuration = 60f; // Game duration in seconds
    public GameObject newSpaceshipPanel;
    public static float playerMoveTime;
    private int finalScore;
    private int currentLevel;
    int mt;
    private string path = Path.Combine(Application.dataPath, "Patient_Data", "ScoreManager.csv");
    private PlayerScore Playerscore;
    private float timer;
    public static bool changeScene = false;
    public readonly string nextScene = "calibrationScene";
    // Start is called before the first frame update
    void Start()
    {
        playerMoveTime = 0;
        MarsComm.OnButtonReleased += onMarsButtonReleased;
        Playerscore = FindObjectOfType<PlayerScore>();
        timer = gameDuration; // Initialize timer 
        GameOverPanel.SetActive(false);
        if (File.Exists(path))
        {
            string[] lines = File.ReadAllLines(path);
            string[] values = lines[0].Split(','); // Split the line by commas
            if (values.Length >= 2)
            {

                int.TryParse(values[1], out currentLevel); // Parse the second value as currentLevel
            }
        }
        StartNewGameSession();
        //support.text = $"Support : {AppData.ArmSupportController.getGain()}%";
        SupportSlider.fillAmount = MarsComm.SUPPORT;
       
    }

    // Update is called once per frame
    void Update()
    {
        //angeltext.text = MarsComm.angleOne + "\\" + MarsComm.angleTwo + "\\" + MarsComm.angleThree + "\\" + MarsComm.angleFour;
        // Check if the Escape key is pressed
        if (Input.GetKeyDown(KeyCode.Escape) || isGameOver)
        {
            // GameOverPanel.SetActive(true);
            GameOver();
        }
        else
        { // Countdown the timer
            timer -= Time.deltaTime;
            playerMoveTime += Time.deltaTime;
            gameData.playerScore = Playerscore.currentScore;
            // Update the timer display
            if (timerText != null)
            {
                timerText.text = "Time:" + Mathf.CeilToInt(timer).ToString() + "s"; // Show remaining time
            }
        }

        // Check if the timer has reached zero
        if (timer <= 0)
        {
            timer = 0;
            GameOver();
        }

        if (changeScene && isGameOver)
        {
            Debug.Log("button working");
            //reStartGame();
            restart();
            changeScene = false;
        }
        else
        {
            changeScene = false;
        }
        updateMarsSupportUI();
    }
    public void updateMarsSupportUI()
    {
        //support.text = $"Support : {AppData.ArmSupportController.getGain()}%";
        SupportSlider.fillAmount = MarsComm.SUPPORT;
    }
    void StartNewGameSession()
    {
        currentGameSession = new GameSession
        {
            GameName = "spaceShooter",
            Assessment = 0 // Example assessment value, 
                           //If this script for calibration and assessment then Assessment=1. 
        };
        SessionManager.Instance.StartGameSession(currentGameSession);
        SetSessionDetails();
    }

    public void SetSessionDetails()
    {
        string device = "MARS"; // Set the device name
        string assistMode = "Null"; // Set the assist mode
        string assistModeParameters = "Null"; // Set the assist mode parameters
        string deviceSetupLocation = DataManager.filePathforConfig;
        SessionManager.Instance.SetDevice(device, currentGameSession);
        SessionManager.Instance.SetAssistMode(assistMode, assistModeParameters, currentGameSession);
        SessionManager.Instance.SetDeviceSetupLocation(deviceSetupLocation, currentGameSession);
        SessionManager.Instance.mechanism(MarsDefs.Movements[1], currentGameSession);

    }
    void EndCurrentGameSession()
    {
        if (currentGameSession != null)
        {
            string trialDataFileLocation = AppData.trialDataFileLocation;
            string gameParameter = "pass_game_parameter";
            SessionManager.Instance.SetGameParameter(gameParameter, currentGameSession);
            SessionManager.Instance.SetTrialDataFileLocation(trialDataFileLocation, currentGameSession);
            mt = (int)playerMoveTime;
            SessionManager.Instance.moveTime(mt.ToString(), currentGameSession);
            SessionManager.Instance.EndGameSession(currentGameSession);
        }
    }
    public void onMarsButtonReleased()
    {
        AppLogger.LogInfo("Mars button released.");
        changeScene = true;

    }

    private void savedata()
    {
        //using the currentscore variable in playerscore to append the player score in csv file when game ends
        int currentscores = Playerscore.currentScore;
        string score = $"{currentscores},{currentLevel}";
        File.WriteAllText(path, score);

    }

    public void GameOver()
    {

        if (Levelunlocked == false)
        {

            GameOverPanel.SetActive(true);
            EndCurrentGameSession();
            gameData.StopLogging();
            savedata();
        }

        timerText.text = "Time:0s";
        isGameOver = true; // Set game over state 

    }
    public void restart()
    {
        string currentSceneName = SceneManager.GetActiveScene().name;
        AppLogger.LogInfo($"The Game is Restarted '{currentSceneName}'.");

        SceneManager.LoadScene(currentSceneName);
    }
    public void Back_to_ChooseLevel()
    {
        SceneManager.LoadScene("space_shooter_level");
    }
    public void UnlockShipPanel()
    {
        if (newSpaceshipPanel != null)
        {
            newSpaceshipPanel.SetActive(true);
            Levelunlocked = true;
            GameOver();

        }

    }
    public void secondlevel()
    {

        finalScore = 0;
        if (currentLevel <= 2)
        {
            currentLevel = 2;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level2");
    }
    public void thirdlevel()
    {
        finalScore = 0;
        if (currentLevel <= 3)
        {
            currentLevel = 3;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level3");

    }
    public void fourthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 4)
        {
            currentLevel = 4;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level4");

    }
    public void fifthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 5)
        {
            currentLevel = 5;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level5");

    }
    public void sixthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 6)
        {
            currentLevel = 6;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level6");

    }
    public void seventhlevel()
    {
        finalScore = 0;
        if (currentLevel <= 7)
        {
            currentLevel = 7;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level7");
    }
    public void eigthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 8)
        {
            currentLevel = 8;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level8");
    }
    public void ninthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 9)
        {
            currentLevel = 9;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level9");
    }
    public void tenthlevel()
    {
        finalScore = 0;
        if (currentLevel <= 10)
        {
            currentLevel = 10;
        }
        string data = $"{finalScore},{currentLevel}";
        File.WriteAllText(path, data);
        SceneManager.LoadScene("SpaceShooter_Level9");
    }
    private void OnApplicationQuit()
    {
        Application.Quit();
        JediComm.Disconnect();
    }
}
