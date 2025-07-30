//using PlutoDataStructures;

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

//using Michsky.UI.ModernUIPack;
public class FlappyGameControl : MonoBehaviour
{
    // public hyper1 h;
    public AudioClip[] winClip;
    public AudioClip[] hitClip;
    public Text ScoreText;
    //public ProgressBar timerObject;
    public static FlappyGameControl instance;
    
    //public RockVR.Video.VideoCapture vdc;
    public GameObject GameOverText;
    public GameObject CongratulationsText;
    public bool gameOver = false;
    public bool gamestarted = false;
    //public float scrollSpeed = -1.5f;
    public float scrollSpeed;
    private int score;
    public GameObject[] pauseObjects;
    public float gameduration = 90*5;
 
    public static bool playermoving = false;
    //public float gameduration = PlayerPrefs.GetFloat("");
    public GameObject start;
    int win = 0;
    bool endValSet = false;
    int mt;
    public int startGameLevelSpeed=1;
    public int startGameLevelRom = 1;
    public float ypos;
    public static float playerMoveTime;
    public GameObject menuCanvas;
    public GameObject Canvas;

    public BirdControl bc;

    public Text durationText;
    private int duration = 0;
    IEnumerator timecoRoutine;
    bool column_position_flag;
    public static bool column_position_flag_topass;

    public Text LevelText;

    public static string start_time;
    string end_time;
    string p_hospno;
    int hit_count;

    float start_speed;
    public static float auto_speed = -2.0f;

    int total_life = 3;

    DateTime last_three_duration;

    string  path_to_data;
    public Text support;
    public float supporti;
    public float gameTime;
    public static bool changeScene = false;
    public static int flappyGameCount;

    void Awake()
    {
        if (instance == null)
        {
            instance = this;
        }
        else if (instance != null)
        {
            Destroy(gameObject);
        }
        //AppData.game = "FLAPPY BIRD";

    }


    // Start is called before the first frame update
    void Start()
    {
        playerMoveTime = 0;
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        path_to_data = Application.dataPath;
        flappyGameCount++;
        LevelText.enabled = false;
        scrollSpeed = -(PlayerPrefs.GetFloat("ScrollSpeed"));
        Time.timeScale = 1;
        ShowGameMenu();
        column_position_flag = false;
     
        //support.text = "Support: " + Mathf.Round(weightEstimation.support * 100.0f).ToString() + " %";
    }

    // Update is called once per frame
    void Update()
    {      

        LevelText.text = "Level: " + auto_speed*(-0.5);


      

        column_position_flag_topass = column_position_flag;
        
       
        //uses the p button to pause and unpause the game
        if ((Input.GetKeyDown(KeyCode.P)))
        {
            if (!gameOver)
            {
                if (Time.timeScale == 1)
                {
                    Time.timeScale = 0;
                    showPaused();
                }
                else if (Time.timeScale == 0)
                {
                    Time.timeScale = 1;
                    hidePaused();
                }
            }
            else if (gameOver)
            {

                hidePaused();
                playAgain();
                
            }
        }
        

        if (!gameOver && Time.timeScale == 1)
        {
            playerMoveTime += Time.deltaTime;
           
            gameduration -= Time.deltaTime;
        }


       
        if (changeScene)
        {
            Debug.Log("button working");
            //reStartGame();
            if (!gameOver && gamestarted)
            {
                if (Time.timeScale == 1)
                {
                    Time.timeScale = 0;
                    showPaused();
                }
                else if (Time.timeScale == 0)
                {
                    Time.timeScale = 1;
                    hidePaused();
                }
            }
            else if (gameOver && gamestarted)
            {
                Debug.Log("playagain");
                hidePaused();
                playAgain();

            }
            else if(!gamestarted)
            {
                StartGame();
                gamestarted = true; 
            }
            changeScene = false;
           
        }
        else
        {
            changeScene = false;
        }


    }
    public void onMarsButtonReleased()
    {
        AppLogger.LogInfo("Mars button released.");
        changeScene = true;

    }
  
    

   
    //shows objects with ShowOnPause tag
    public void showPaused()
    {
      
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(true);
        }
    }

    //hides objects with ShowOnPause tag
    public void hidePaused()
    {
        
        foreach (GameObject g in pauseObjects)
        {
            g.SetActive(false);
        }
    }
    public void BirdDied()
    {
        GameOverText.SetActive(true);
        gameOver = true;
        end_time = DateTime.Now.ToString("HH:mm:ss tt");  
        System.DateTime today = System.DateTime.Today;
        float start_speed_csv = start_speed;
        float end_speed = auto_speed;
        string duration_played = (DateTime.Parse(end_time)-DateTime.Parse(start_time)).ToString();
        hit_count = BirdControl.hit_count;
        Debug.Log(today + ".." + start_time + ".." + end_time + ".." + start_speed_csv + ".." + end_speed + ".." + duration_played + ".." + hit_count);

        //string newFileName = @"C:\Users\BioRehab\Desktop\Sathya\unity-pose\Arebo demo\Data\" + p_hospno + "\\" + "flappy_hits.csv";
        string newFileName = path_to_data + "\\" + "Patient_Data" + "\\" + p_hospno + "\\" + "flappy_hits.csv";
        string data_csv = today.ToString() + "," + start_speed_csv + "," + end_speed + "," + start_time + "," + end_time + "," + duration_played + "," + hit_count + "\n";
        File.AppendAllText(newFileName, data_csv);
    }

    public void Birdalive()
    {
        CongratulationsText.SetActive(true);
        gameOver = true;
        end_time = DateTime.Now.ToString("HH:mm:ss tt");  
        System.DateTime today = System.DateTime.Today;
        float start_speed_csv = start_speed;
        float end_speed = auto_speed;
        string duration_played = (DateTime.Parse(end_time)-DateTime.Parse(start_time)).ToString();
        hit_count = BirdControl.hit_count;
        Debug.Log(today + ".." + start_time + ".." + end_time + ".." + start_speed_csv + ".." + end_speed + ".." + duration_played + ".." + hit_count);

        //string newFileName = @"C:\Users\BioRehab\Desktop\Sathya\unity-pose\Arebo demo\Data\" + p_hospno + "\\" + "flappy_hits.csv";
        string newFileName = path_to_data + "\\" + "Patient_Data" + "\\" + p_hospno + "\\" + "flappy_hits.csv";
        string data_csv = today.ToString() + "," + start_speed_csv + "," + end_speed + "," + start_time + "," + end_time + "," + duration_played + "," + hit_count + "\n";
        File.AppendAllText(newFileName, data_csv);
    }

    public void BirdScored()
    {
        if (!bc.startBlinking )
        {
            score += 1;
            
        }
       
        ScoreText.text = "Score: " + score.ToString();
        FlappyColumnPool.instance.spawnColumn();

    }
    

    public void RandomAngle()
    {
        ypos = UnityEngine.Random.Range(-3f, 5.5f);
    }

    public void playAgain()
    {
        if (gameOver == true)
        {
            
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);

        }
        if (!gameOver)
        {
            if (Time.timeScale == 1)
            {
                Time.timeScale = 0;
                showPaused();
            }
            else if (Time.timeScale == 0)
            {
                Time.timeScale = 1;
                hidePaused();
            }

        }

    }
    public void PlayStart()
    {
        endValSet = false;
        start.SetActive(false);
        Time.timeScale = 1;
        
    }

    public void continueButton() {
          if (Time.timeScale == 0)
        {
            Time.timeScale = 1;
            hidePaused();

        }
    }

    public void ShowGameMenu()
    {
        
        menuCanvas.SetActive(true);
        Canvas.SetActive(false);
        Time.timeScale = 0;
    }

    public void StartGame()
    {
        gameOver = false;
        start_time = DateTime.Now.ToString("HH:mm:ss tt");
        Canvas.SetActive(true);
        menuCanvas.SetActive(false);
        Time.timeScale = 1;
        timecoRoutine = SpawnTimer();
        duration = 60;
        StartCoroutine(timecoRoutine);
      
        // var lines = File.ReadAllLines(@"C:\Users\BioRehab\Desktop\Sathya\unity-pose\Arebo demo\Data\"+p_hospno+"\\"+"flappy_hits.csv");
        var lines = File.ReadAllLines(path_to_data+"\\"+"Patient_Data"+"\\"+p_hospno+"\\"+"flappy_hits.csv");
        
        var count = lines.Length;
        List<string> second_row = new List<string>();
        List<string> fifth_row = new List<string>();
        List<string> sixth_row = new List<string>();
        //if (count>1)
        //{
        //    foreach (var item in lines)
        //    {
        //        var rowItems = item.Split(',');
        //        second_row.Add(rowItems[2]);
        //        fifth_row.Add(rowItems[5]);
        //        sixth_row.Add(rowItems[6]);
        //    }
            
        //    auto_speed = float.Parse(second_row[count-1]);
        //    if(auto_speed<0)
        //    {
        //        start_speed = auto_speed;
        //    }
        //    else
        //    {
        //        auto_speed = -2.0f;
        //        start_speed = auto_speed;
        //    }

            
            
        //}
        //else
        //{
        //    auto_speed = -2.0f;
        //    start_speed = auto_speed;
        //}

        
    }

    private IEnumerator SpawnTimer() {
		while (!gameOver){

			duration = duration-1;
			UpdateDuration ();

			if(duration == 0){
                gameOver = true;
                duration = 60;
                Birdalive();
                total_life = total_life-1;
                if(total_life<0)
                {
                    //auto_speed = auto_speed-2.0f;
                } 
			}

			yield return new WaitForSeconds(1);
			
		}	

	}

    void UpdateDuration ()
	{
		durationText.text = "Duration: " + duration;
		
	}

    

    public void continue_pressed()
    {
        StartGame();
        GameOverText.SetActive(false);
        CongratulationsText.SetActive(false);
        gameOver = false;
    }

    public void quit_pressed()
    {
      
        SceneManager.LoadScene("chooseMovementScene");
    }
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }

    public void OnApplicationQuit()
    {
        JediComm.Disconnect();
        Application.Quit();
      
      
    }

    
}
