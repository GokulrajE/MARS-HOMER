using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;
using TMPro;
using UnityEngine.UI;



public class assessROM : MonoBehaviour
{
    public string marsMode {  get; private set; }
    public GameObject fws;
    public GameObject hws;
    public GameObject nws;
    public Image fwsTick;
    public Image hwsTick;
    public Image nwsTick;
    public Text fwsText;
    public Text hwsText;
    public Text nwsText;
    public Text message;
    Image panelFWS;
    Image panelHWS;
    Image panelNWS;
    public bool changeScene = false,
                isFinished = false;
   
    public enum MARSMODE
    {
        NONE,
        FWS,
        HWS,
        NWS,
    }
    public MARSMODE transCtrlMode = MARSMODE.NONE;

    void Start()
    {
        
        initUI();
        setMarsMode();
        updateUI();
        attachcallback();
        
    }
    public void attachcallback()
    {
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");

        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();
       
        if (AppData.Instance.selectedMovement.MarsMode != null && changeScene)
        {
            
           runStateMachine();   
          
        }
        if (isFinished)
        {
            isFinished = false;
            SceneManager.LoadScene("CHOOSEMOVEMENT");
        }

    }
    public void runStateMachine()
    {
        switch (transCtrlMode)
        {
            case MARSMODE.NONE:
                break;
            case MARSMODE.FWS:
                if (MarsComm.target != 1.0f)
                {
                    AppData.Instance.transitionControl.setFWS();
                    return;
                }
                SceneManager.LoadScene("DRAWAREA");
                break;
            case MARSMODE.HWS:
                if (MarsComm.target != 0.5f)
                {
                    AppData.Instance.transitionControl.setHWS();
                    return;
                }
                SceneManager.LoadScene("DRAWAREA");
                break;
            case MARSMODE.NWS:
                if (MarsComm.target != 0.0f)
                {
                    AppData.Instance.transitionControl.setNWS();
                    return;
                }
                SceneManager.LoadScene("DRAWAREA");
                break;
        }
        changeScene = false;
    }
    public void OnMarsButtonReleased()
    {
     
       if(!AppData.Instance.selectedMovement.aromCompletedFWS|| !AppData.Instance.selectedMovement.aromCompletedHWS || !AppData.Instance.selectedMovement.aromCompletedNWS)
       {
            changeScene = true;
       }
        else
        {
          AppData.Instance.selectedMovement.SaveAssessmentData();     
          isFinished = true;
        }

    }
    public void initUI()
    {

        panelFWS = fws.GetComponent<Image>();
        panelHWS = hws.GetComponent<Image>();
        panelNWS = nws.GetComponent<Image>();

        panelFWS.color = new Color32(60, 60, 60, 255); ; // grey
        panelHWS.color = new Color32(60, 60, 60, 255); ; // grey
        panelNWS.color = new Color32(60, 60, 60, 255); ; // grey
      
        fwsText.text = "";
        hwsText.text = "";
        nwsText.text = "";
    }
    public void setMarsMode()
    {
        if (!AppData.Instance.selectedMovement.aromCompletedFWS)
        {
            panelFWS.color = new Color32(251, 139, 30, 255);  // Orange
            transCtrlMode = MARSMODE.FWS;
            AppData.Instance.selectedMovement.setMode("FWS");
            message.text = "press mars button to access ROM for FWS";
            return;
        }
        else if (!AppData.Instance.selectedMovement.aromCompletedHWS)
        {
            panelHWS.color = new Color32(251, 139, 30, 255);  // Orange
            transCtrlMode = MARSMODE.HWS;
            AppData.Instance.selectedMovement.setMode("HWS");
        
            message.text = "press mars button to access ROM for HWS";
            return;

        }
        else if (!AppData.Instance.selectedMovement.aromCompletedNWS)
        {
            panelNWS.color = new Color32(251, 139, 30, 255);  // Orange
            transCtrlMode = MARSMODE.NWS;
            AppData.Instance.selectedMovement.setMode("NWS");
      
            message.text = "press mars button to access ROM for NWS";
            return;
        }
        if (AppData.Instance.selectedMovement.aromCompletedFWS || AppData.Instance.selectedMovement.aromCompletedHWS || AppData.Instance.selectedMovement.aromCompletedNWS)
        {
            message.text = "press mars button to save ROM data";
        }


    }
    public void updateUI()
    {
        if (AppData.Instance.selectedMovement.aromCompletedFWS)
        {
            fwsTick.enabled = true;
            fwsText.text = $"MIN-X : {AppData.Instance.selectedMovement.CurrentAromFWS[0]}\n" +
                           $"MAX-X : {AppData.Instance.selectedMovement.CurrentAromFWS[1]}\n" +
                           $"MIN-Y : {AppData.Instance.selectedMovement.CurrentAromFWS[2]}\n" +
                           $"MAX-Y : {AppData.Instance.selectedMovement.CurrentAromFWS[3]}";

        }
        if (AppData.Instance.selectedMovement.aromCompletedHWS)
        {
           
            hwsTick.enabled = true;
            hwsText.text = $"MIN-X : {AppData.Instance.selectedMovement.CurrentAromHWS[0]}\n" +
                           $"MAX-X : {AppData.Instance.selectedMovement.CurrentAromHWS[1]}\n" +
                           $"MIN-Y : {AppData.Instance.selectedMovement.CurrentAromHWS[2]}\n" +
                           $"MAX-Y : {AppData.Instance.selectedMovement.CurrentAromHWS[3]}";

        }
        if (AppData.Instance.selectedMovement.aromCompletedNWS)
        {
           
            nwsTick.enabled = true;
            nwsText.text = $"MIN-X : {AppData.Instance.selectedMovement.CurrentAromNWS[0]}\n" +
                           $"MAX-X : {AppData.Instance.selectedMovement.CurrentAromNWS[1]}\n" +
                           $"MIN-Y : {AppData.Instance.selectedMovement.CurrentAromNWS[2]}\n" +
                           $"MAX-Y : {AppData.Instance.selectedMovement.CurrentAromNWS[3]}";

        }
    }
    public void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}

