using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using UnityEngine.SceneManagement;
using System.Linq;
using System;
using UnityEngine.UI;
using UnityEditor;
using TMPro;
public class RangOfMotion : MonoBehaviour
{
    public static RangOfMotion instance;
    public float[] Encoder = new float[6];
    public float[] ELValue = new float[6];
    public float max_x;
    public float min_x;
    public float max_y;
    public float min_y;
    public GameObject message;
    public static int inclusion;
    public static string currentDate;
    public Slider force;
    public Image supportIndicator;
    public TextMeshProUGUI support;
    public GameObject messagePanel;
    List<Vector3> paths;

  
    void Awake()
    {
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        instance = this;
        Time.timeScale = 1;
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
        //AppData.Instance.InitializeRobot();
        //AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        //AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        //AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        messagePanel.SetActive(false);
        paths = new List<Vector3>();
        message.SetActive(false);
        currentDate = (DateTime.Now.ToString("MM-dd-yyyy-HH-mm-ss"));
    }

    public void Update()
    {
       
        //updateSupportGUI();

        //if(MarsComm.SUPPORT <= MarsComm.SUPPORT_CODE[2] || MarsComm.SUPPORT<0.55f)
        //{
        //    Debug.Log("Half weight support initiated");
        //    AppLogger.LogInfo("half weight support initiated");
        //    SceneManager.LoadScene("halfWeightSupportScene");
        //}
      
       
    }

    public void onclick_recalibrate()
    {
        SceneManager.LoadScene("fullWeightSupportScene");

    }
    public void onclickHalfweightSupport()
    {
        //AppData.ArmSupportController.UseHalfWeightSupport(1);
        paths = Drawlines.paths_pass;
        max_x = paths.Max(v => v.x);
        min_x = paths.Min(v => v.x);
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);
        //Debug.LogError(max_x + ";" + min_x + ";" + max_y + ";" + min_y);
        if (Mathf.Abs(max_x-min_x) > 100|| Mathf.Abs(max_y - min_y) > 100)
        {
            inclusion = 1;
            message.SetActive(true);
            messagePanel.SetActive(true);
            //string headerData = "startdate,Max_x,Min_x,Max_y,Min_y";
            DateTime time = DateTime.Now;
            string data = time.ToString() + "," + max_x + "," + min_x + "," + max_y + "," + min_y;
           
            //AppData.writeAssessmentData(headerData, data, DataManager.ROMWithSupportFileNames[0],DataManager.directoryAssessmentData);
        }
        else
        {
            inclusion = 0;
            message.SetActive(false);
        }
     
    }
    public void OnMarsButtonReleased()
    {
       saveAssessmentData();

    }

    public void saveAssessmentData()
    {
        //save Assessment data 
        //AppData.Instance.selectedMovement.newRom.SetMovement("SABDU");
        //AppData.Instance.selectedMovement.newRom.SetMarsMode("FWS");
        AppData.Instance.selectedMovement.SetNewRomValuesFWS(max_x, min_x, max_y, min_y);
        AppData.Instance.selectedMovement.SaveAssessmentData();

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

