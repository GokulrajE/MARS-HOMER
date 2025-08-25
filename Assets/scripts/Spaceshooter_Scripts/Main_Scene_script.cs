
using System.Collections;
using System.Collections.Generic;
//using UnityEditor.SearchService;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Main_Scene_script : MonoBehaviour
{
  
    public static bool changeScene = false;
    public readonly string nextScene = "space_shooter_level";
    // Start is called before the first frame update
    void Start()
    {
        // Attach mars button event
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
      
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();

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

    public void onClick_gotoLevel()
    {
        SceneManager.LoadScene("space_shooter_level");
    }
    public void onclick_gotochoose()
    {
        SceneManager.LoadScene("CHOOSEMOVEMENT");
    }
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
}
