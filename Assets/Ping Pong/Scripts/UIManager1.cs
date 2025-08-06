using UnityEngine;
using System.Collections;
using UnityEngine.SceneManagement;


public class UIManager1 : MonoBehaviour {

    GameObject[]  finishObjects;
	public BoundController rightBound;
	public BoundController leftBound;
	
    public AudioClip[] audioClips; // winlevel loose
   
    
    public static bool changeScene = false;
    public readonly string nextScene = "pong_game";
    // Use this for initialization
    void Start () {
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
       
        finishObjects = GameObject.FindGameObjectsWithTag("ShowOnFinish");
		hideFinished();
        
	}
	// Update is called once per frame
	void Update () {


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

    void playAudio(int clipNumber)
    {
        AudioSource audio = GetComponent<AudioSource>();
        audio.clip = audioClips[clipNumber];
        audio.Play();

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
		SceneManager.LoadScene("CHOOSEMOVEMENT");
	}
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
}
