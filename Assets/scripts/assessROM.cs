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
    public Image fwstick;
    public Image hwstick;
    public Image nwstick;
    public Text fwstext;
    public Text hwstext;
    public Text nwstext;
    public Text message;
    Image panelfws;
    Image panelhws;
    Image panelnws;
    public bool changeScene = false;
    public bool attachMarsButtonEvent = false;
    // Start is called before the first frame update
  

    void Start()
    {
        
        initUI();
        checkMarsMode();
        updateUI();
        attachcallback();
        
    }
    public void attachcallback()
    {
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
    }

    // Update is called once per frame
    void Update()
    {
        if (AppData.Instance.selectedMovement.MarsMode!= null && changeScene)
        {
            SceneManager.LoadScene("DRAWAREA");
            changeScene = false;
        }
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
        }

    }
    public void initUI()
    {

        panelfws = fws.GetComponent<Image>();
        panelhws = hws.GetComponent<Image>();
        panelnws = nws.GetComponent<Image>();

        panelfws.color = new Color32(89, 77, 77, 238); ; // grey
        panelhws.color = new Color32(89, 77, 77, 238); ; // grey
        panelnws.color = new Color32(89, 77, 77, 238); ; // grey
      
        fwstext.text = "";
        hwstext.text = "";
        nwstext.text = "";
    }
    public void checkMarsMode()
    {
        if (!AppData.Instance.selectedMovement.aromCompletedFWS)
        {
            panelfws.color = new Color32(251, 139, 30, 255);  // Orange
            AppData.Instance.selectedMovement.setMode("FWS");
            message.text = "press mars button to access ROM for FWS";
            return;
        }
        else if (!AppData.Instance.selectedMovement.aromCompletedHWS)
        {
            panelhws.color = new Color32(251, 139, 30, 255);  // Orange
            AppData.Instance.selectedMovement.setMode("HWS");
            message.text = "press mars button to access ROM for HWS";
            return;

        }
        else if (!AppData.Instance.selectedMovement.aromCompletedNWS)
        {
            panelnws.color = new Color32(251, 139, 30, 255);  // Orange
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
            fwstick.enabled = true;
           
        }
        if (AppData.Instance.selectedMovement.aromCompletedHWS)
        {
           
            hwstick.enabled = true;

        }
        if (AppData.Instance.selectedMovement.aromCompletedNWS)
        {
           
            nwstick.enabled = true;
          
        }
    }
    public void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}

