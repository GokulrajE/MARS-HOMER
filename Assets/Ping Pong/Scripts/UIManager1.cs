using UnityEngine;
using System.Collections;
using UnityEngine.SceneManagement;
using NeuroRehabLibrary;

public class UIManager1 : MonoBehaviour {

    private GameSession currentGameSession;
    GameObject[] pauseObjects, finishObjects;
	public BoundController rightBound;
	public BoundController leftBound;
	public bool isFinished;
	public bool playerWon, enemyWon;
    public AudioClip[] audioClips; // winlevel loose
    public int winScore = 7;
    public int win;
    public int mt;
    public static float playerMoveTime;
    public static bool changeScene = false;
    public readonly string nextScene = "pong_game";
    // Use this for initialization
    void Start () {
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        //pauseObjects = GameObject.FindGameObjectsWithTag("ShowOnPause");
        finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");
		hideFinished();
        
	}
	// Update is called once per frame
	void Update () {

		//Debug.Log(AppData.inputPressed());



        if (Input.GetKeyDown(KeyCode.Return))
        {

         

            LoadLevel("pong_game");
        }

        // Check if it time to switch to the next scene
        if (changeScene == true)
        {
            LoadTargetScene();
            changeScene = false;
        }
    }

    public void onMarsButtonReleased()
    {
        AppLogger.LogInfo("Mars button released.");
        changeScene = true;

    }

    private void LoadTargetScene()
    {
        AppLogger.LogInfo($"Switching to the next scene '{nextScene}'.");
        SceneManager.LoadScene(nextScene);
    }


   

    //Reloads the Level
    public void Reload(){
		Application.LoadLevel(Application.loadedLevel);
	}
    void playAudio(int clipNumber)
    {
        AudioSource audio = GetComponent<AudioSource>();
        audio.clip = audioClips[clipNumber];
        audio.Play();

    }
    //controls the pausing of the scene
    public void pauseControl(){
		if(Time.timeScale == 1)
		{
			Time.timeScale = 0;
			showPaused();
		} else if (Time.timeScale == 0){
			Time.timeScale = 1;
			hidePaused();
		}
	}
	
	//shows objects with ShowOnPause tag
	public void showPaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(true);
		}
	}

	//hides objects with ShowOnPause tag
	public void hidePaused(){
		foreach(GameObject g in pauseObjects){
			g.SetActive(false);
		}
	}

	//shows objects with ShowOnFinish tag
	public void showFinished(){
      

        foreach (GameObject g in finishObjects){
			g.SetActive(true);
		}
	}
	
	//hides objects with ShowOnFinish tag
	public void hideFinished(){
		foreach(GameObject g in finishObjects){
			g.SetActive(false);
		}
	}
	

	//loads inputted level
	public void LoadLevel(string level){

		SceneManager.LoadSceneAsync(level);
	}

	public void Exit()
    {
		SceneManager.LoadScene("chooseMovementScene");
	}
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
}
