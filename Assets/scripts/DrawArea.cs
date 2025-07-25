using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;
using JetBrains.Annotations;
using System;
public class DrawArea : MonoBehaviour
{
    float max_x, max_y, min_x, min_y;
    List<Vector3> paths;
    public assessROM ass;
    public bool changeScene = false;
    // Start is called before the first frame update
    void Start()
    {
        
        resetROM();
        MarsComm.OnMarsButtonReleased += OnMarsButtonReleased;
    }

    // Update is called once per frame
    void Update()
    {
        if (changeScene)
        {
           
            SceneManager.LoadScene("ASSESSROM");

            changeScene = false;
        }

    }
    public void OnMarsButtonReleased()
    {
        //Debug.Log("marsbuttonreleased");
        setAssessmentData();
        
    }
    public void setAssessmentData()
    {
        
        paths = Drawlines.paths_pass;
        max_x = paths.Max(v => v.x);
        min_x = paths.Min(v => v.x);
        max_y = paths.Max(v => v.y);
        min_y = paths.Min(v => v.y);

        //save Assessment data 
      
        switch (AppData.Instance.selectedMovement.MarsMode)
        {
            case "FWS" :
                AppData.Instance.selectedMovement.SetNewRomValuesFWS(max_x, min_x, max_y, min_y);
                break;
            case "HWS":
                AppData.Instance.selectedMovement.SetNewRomValuesHWS(max_x, min_x, max_y, min_y);
                break;
            case "NWS":
                AppData.Instance.selectedMovement.SetNewRomValuesNWS(max_x, min_x, max_y, min_y);
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
        SceneManager.LoadScene("ASSROM");

    }
    public void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}
