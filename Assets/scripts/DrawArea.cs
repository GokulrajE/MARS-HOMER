
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;
using UnityEngine.UI;
using System;
public class DrawArea : MonoBehaviour
{
    float epmaxX, epmaxY, epminX, epminY;
    List<Vector3> endPoints;
    List<Vector3> unityPoints;
    public static DrawArea instance;

    public bool changeScene = false;

    public Text timerUITxt;
    public Text messageTxt;
    public Text rightText;
    public Text thersholdText;
    public Image Timer;
    public Image rightImage;
    public Image leftImage;

    public float countDown = -1;
    void Start()
    { 
        instance = this;
        Timer.gameObject.SetActive(false);
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");

        resetROM();
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
        if(AppData.Instance.selectedMovement.MarsMode != "FWS")
           countDown = 6;
       
        if(AppData.Instance.selectedMovement.name == "ELFE")
        {
            rightImage.transform.rotation = Quaternion.Euler(new Vector3(0, 0, 90));
            leftImage.transform.rotation = Quaternion.Euler(new Vector3(0, 0, 90));
        }
       
    }

    // Update is called once per frame
    void Update()
    {
        MarsComm.sendHeartbeat();
      
        updateUI();
        if (changeScene)
        {
            SceneManager.LoadScene("ASSESSROM");
            changeScene = false;
        }

    }
    public void updateUI()
    {
        //get lates points
        unityPoints = Drawlines.unityDrawValues;
        endPoints = Drawlines.endPntPos;

        //count down Timer to change the Mars Mode
        if (countDown >= 0)
        {
            //messageTxt.text = "Please wait Mars Mode Onchange";
            countDown -= Time.deltaTime;
            timerUITxt.text = countDown.ToString("F0");
            Timer.gameObject.SetActive(countDown > 0);
            rightImage.gameObject.SetActive(countDown <= 0);
            leftImage.gameObject.SetActive(countDown <= 0);
            return;
        }
        messageTxt.text = "Press Mars Button to Finish";

        //move the Bar Dynamically
        if (unityPoints != null && unityPoints.Count > 0)
        {
            epmaxX = endPoints.Max(v => v.x);
            epminX = endPoints.Min(v => v.x);
            epmaxY = endPoints.Max(v => v.y);
            epminY = endPoints.Min(v => v.y);
            float minX = unityPoints.Min(v => v.x);
            float maxX = unityPoints.Max(v => v.x);
            float minY = unityPoints.Min(v => v.y);
            float maxY = unityPoints.Max(v => v.y);
            Vector3 worldMin;
            Vector3 worldMax;
            // World positions
            if (AppData.Instance.selectedMovement.name == "ELFE")
            {
                worldMin = new Vector3((float)unityPoints[1].x, minY, 0);
                worldMax = new Vector3((float)unityPoints[1].x, maxY, 0);
                thersholdText.text = $"{(Math.Abs(epmaxY - epminY) * 100).ToString("F0")}cm";
            }
            else
            {
                worldMin = new Vector3(minX, (float)Drawlines.centerValY, 0);
                worldMax = new Vector3(maxX, (float)Drawlines.centerValY, 0);
                thersholdText.text = $"{Math.Abs((Math.Abs(epmaxX * 100) - Math.Abs(epminX * 100))).ToString("F0")}cm";

            }


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
            if (AppData.Instance.selectedMovement.name == "ELFE")
            {
                leftImage.rectTransform.anchoredPosition = localMax;
                rightImage.rectTransform.anchoredPosition = localMin;
            }
            else
            {
                leftImage.rectTransform.anchoredPosition = localMin;
                rightImage.rectTransform.anchoredPosition = localMax;

            }

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
                AppData.Instance.selectedMovement.SetNewRomValuesFWS(epminX, epmaxX, epminY, epmaxY);
                break;
            case "HWS":
                AppData.Instance.selectedMovement.SetNewRomValuesHWS(epminX, epmaxX, epminY, epmaxY);
                break;
            case "NWS":
                AppData.Instance.selectedMovement.SetNewRomValuesNWS(epminX, epmaxX, epminY, epmaxY);
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
