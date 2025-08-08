using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class calibrationSceneHandler : MonoBehaviour
{
    //ui related variables
    public TMP_Text messageBox;
    public readonly string nextScene = "CHOOSEMOVEMENT";
    public GameObject panel;
    Image panelImage;
    public bool changeScene;
  

    void Start()
    {
        //AppData.InitializeRobot();
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        //MarsCom.Calibratie();

    }

    void Update()
    {
       


        if (changeScene == true)
        {
            LoadTargetScene();
            changeScene = false;
        }

    }
  
    public void onMarsButtonReleased()
    {
       
    }
  

    private void LoadTargetScene()
    {
        AppLogger.LogInfo($"Switching to the next scene '{nextScene}'.");
        SceneManager.LoadScene(nextScene);
    }

    //To control the motor manually hold and release 
    //public void onClickHold()
    //{
    //    MarsComm.onclickHold();
    //}
    //public void onClickRelease()
    //{
    //    MarsComm.onclickRealease();
    //}


    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
    private void OnApplicationQuit()
    {

        Application.Quit();
        JediComm.Disconnect();
    }
}
