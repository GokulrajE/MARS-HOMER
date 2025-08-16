
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;
using UnityEngine.UI;
using System;
public class DrawArea : MonoBehaviour
{
    float maxX, maxY, minX, minY;
    List<Vector3> paths;
    List<Vector3> unityPaths;

    public bool changeScene = false;

    public Text TimerUITxt;
    public Text messageTxt;
    public Text rightText;
    public Text ThersholdText;
    public Image Timer;
    public Image rightImage;
    public Image leftImage;

    float time;
    void Start()
    {
        
        resetROM();
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        time = 6;
        if (AppData.Instance.selectedMovement.MarsMode == "FWS")
        {
            messageTxt.text = "Press Mars Button to Finish";
        }
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();
        if (time > 0 && AppData.Instance.selectedMovement.MarsMode != "FWS")
        {
            time -= Time.deltaTime;
            TimerUITxt.text = time.ToString("F0");

        }
        else
        {
            Timer.gameObject.SetActive(false);
            messageTxt.text = "Press Mars Button to Finish";

        }

        if (changeScene)
        {
           
            SceneManager.LoadScene("ASSESSROM");

            changeScene = false;
        }
        unityPaths = Drawlines.unityDrawValues;
        paths = Drawlines.endPntPos;
        maxX = paths.Max(v => v.x);
        minX = paths.Min(v => v.x);
        maxY = paths.Max(v => v.y);
        minY = paths.Min(v => v.y);
        ThersholdText.text = $"{ Math.Abs((Math.Abs(maxX*100)-Math.Abs( minX*100))).ToString("F0")}cm";

        if (unityPaths != null && unityPaths.Count > 0)
        {
            float minX = unityPaths.Min(v => v.x);
            float maxX = unityPaths.Max(v => v.x);

            // World positions
            Vector3 worldMin = new Vector3(minX, (float)Drawlines.centerValY, 0);
            Vector3 worldMax = new Vector3(maxX, (float)Drawlines.centerValY, 0);

            // Convert to screen position
            Vector3 screenMin = Camera.main.WorldToScreenPoint(worldMin);
            Vector3 screenMax = Camera.main.WorldToScreenPoint(worldMax);

            // Convert to local UI position (relative to canvas)
            RectTransformUtility.ScreenPointToLocalPointInRectangle(
                rightImage.canvas.transform as RectTransform,
                screenMin,
                rightImage.canvas.worldCamera,
                out Vector2 localMin);

            RectTransformUtility.ScreenPointToLocalPointInRectangle(
                leftImage.canvas.transform as RectTransform,
                screenMax,
                leftImage.canvas.worldCamera,
                out Vector2 localMax);

            // Apply positions
            leftImage.rectTransform.anchoredPosition = localMin;
            rightImage.rectTransform.anchoredPosition = localMax;
        }


    }

    public void OnMarsButtonReleased()
    {
        //Debug.Log("marsbuttonreleased");
        setAssessmentData();
        
    }
    public void setAssessmentData()
    {

        //save Assessment data 
      
        switch (AppData.Instance.selectedMovement.MarsMode)
        {
            case "FWS" :
                AppData.Instance.selectedMovement.SetNewRomValuesFWS(minX, maxX, minY, maxY);
                break;
            case "HWS":
                AppData.Instance.selectedMovement.SetNewRomValuesHWS(minX, maxX, minY, maxY);
                break;
            case "NWS":
                AppData.Instance.selectedMovement.SetNewRomValuesNWS(minX, maxX, minY, maxY);
                break;

        }
        changeScene = true;

    }
    public void resetROM()
    {
        switch (AppData.Instance.selectedMovement.MarsMode)
        {
            case "FWS":
                AppData.Instance.selectedMovement.ResetRomValuesFWS();
                break;
            case "HWS":
                AppData.Instance.selectedMovement.ResetRomValuesHWS();
                break;
            case "NWS":
                AppData.Instance.selectedMovement.ResetRomValuesNWS();
                break;

        }
    }

    public void onclick_recalibrate()
    {
        SceneManager.LoadScene("DRAWAREA");

    }
    public void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}
