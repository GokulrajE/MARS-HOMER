using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.SceneManagement;
using System.IO;
using System.Linq;

using TMPro;
using UnityEngine.UI;

public class HalfWeightSupportROM : MonoBehaviour
{

    List<Vector3> paths;
    public GameObject messagePanel;
    public Image supportIndicator;
    public TextMeshProUGUI support;
    float max_x,max_y,min_x,min_y;

    void Awake()
    {
        //MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;

    }


    void Start()
    {
        //Debug.Log(DataManager.basePath);
        //if (!Directory.Exists(DataManager.basePath))
        //{

        //    SceneManager.LoadScene("getConfig");
        //    return;
        //}

        //// Get all subdirectories excluding metadata
        //var validUserDirs = Directory.GetDirectories(DataManager.basePath)
        //.Select(Path.GetFileName)
        //.Where(name => !name.ToLower().Contains("meta"))
        //.ToList();


        //if (validUserDirs.Count == 1)
        //{
        //    AppData.Instance.setUser(validUserDirs[0]);
        //    DataManager.setUserId(AppData.Instance.userID);
        //}

        //if (!File.Exists(DataManager.filePathforConfig))
        //{

        //    SceneManager.LoadScene("getConfig");
        //    return;
        //}

        //AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        ////AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        ////AppData.Instance.InitializeRobot();
        //AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        //AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        //AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        ////AppData.Instance.InitializeRobot();
        ////messagePanel.SetActive(false);
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;

    }

    public void Update()
    {
      
       // if(MarsComm.SUPPORT == MarsComm.SUPPORT_CODE[0])
       // {
       //     AppLogger.LogInfo("half weight support initiated");
       //     SceneManager.LoadScene("noWeightSupportScene");
       // }
       //updateSupportGUI();
    }
    public void OnMarsButtonReleased()
    {
        Debug.Log("marsbuttonreleased");
        saveAssessmentData();

    }

    public void saveAssessmentData()
    {
        paths = Drawlines.paths_pass;
        max_x = paths.Max(v => v.x);
        min_x = paths.Min(v => v.x);
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);

        //save Assessment data 
        if (AppData.Instance.selectedMovement == null)
            AppData.Instance.SetMovement("SABDU");
            //AppData.Instance.selectedMovement.newRom.SetMovement("SABDU");
            //AppData.Instance.selectedMovement.newRom.SetMarsMode("FWS");
            //AppData.Instance.selectedMovement.SetNewRomValuesFWS(max_x, min_x, max_y, min_y);
            //AppData.Instance.selectedMovement.SaveAssessmentData();

    }
    public void onclick_recalibrate()
    {
        SceneManager.LoadScene("halfWeightSupportScene");

    }

    public void onclickNoweightSupport()
    {
      
       
        messagePanel.SetActive(true);
        paths = Drawlines.paths_pass;
        max_x = paths.Max(v => v.x);
        min_x = paths.Min(v => v.x);
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);
      
        if (Mathf.Abs(max_x - min_x) > 100 || Mathf.Abs(max_y - min_y) > 100)
        {
           
            
            messagePanel.SetActive(true);
            string headerData = "startdate,Max_x,Min_x,Max_y,Min_y";
            DateTime time = DateTime.Now;
            string data = time.ToString() + "," + max_x + "," + min_x + "," + max_y + "," + min_y;

            //To write assessment data
         
            //AppData.writeAssessmentData(headerData, data, DataManager.ROMWithSupportFileNames[1], DataManager.directoryAssessmentData);
        }
        else
        {
          
                messagePanel.SetActive(false);
            
        }

        //AppData.ArmSupportController.UseNoWeightSupport();
     
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
