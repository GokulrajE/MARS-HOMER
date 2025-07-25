using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;
using System;
using TMPro;
using UnityEngine.UI;
public class NoWeightSupport : MonoBehaviour
{
  
    public float time;
    List<Vector3> paths;
    float max_x, max_y, min_x, min_y;
    public Image supportIndicator;
    public TextMeshProUGUI support;
    void Awake()
    {
       
    }

    void Start()
    {
        AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");

    }

    public void Update()
    {
        updateSupportGUI();
        time += Time.deltaTime;
        System.DateTime currentTime = System.DateTime.Now;
      
    }
    
    public void onclick_recalibrate()
    {
        SceneManager.LoadScene("noWeightSupportScene");

    }
    public void onclickMenu()
    {
       
        paths = Drawlines.paths_pass;
        max_x = paths.Max(v => v.x);
        min_x = paths.Min(v => v.x);
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);
      
        if (Mathf.Abs(max_x - min_x) > 100 || Mathf.Abs(max_y - min_y) > 100)
        {

            string headerData = "startdate,Max_x,Min_x,Max_y,Min_y";
            DateTime time = DateTime.Now;
            string data = time.ToString() + "," + max_x + "," + min_x + "," + max_y + "," + min_y;
            //To write assessment data
           //AppData.writeAssessmentData(headerData, data, DataManager.ROMWithSupportFileNames[2], DataManager.directoryAssessmentData);
        }
       
            AppLogger.LogInfo("NoWeightSupport Done");
            SceneManager.LoadScene("chooseMovementScene");
   

    }
    public void updateSupportGUI()
    {
        supportIndicator.fillAmount = MarsComm.SUPPORT;
        //support.text = $"Support:{AppData.ArmSupportController.getGain()}%";
    }

    private void OnApplicationQuit()
    {

        Application.Quit();
        JediComm.Disconnect();
    }
}
