
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using System.Linq;

public class DrawArea : MonoBehaviour
{
    float maxX, maxY, minX, minY;
    List<Vector3> paths;

    public bool changeScene = false;
   
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
        maxX = paths.Max(v => v.x);
        minX = paths.Min(v => v.x);
        maxY = paths.Max(v => v.y);
        minY = paths.Min(v => v.y);

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
        SceneManager.LoadScene("ASSROM");

    }
    public void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= OnMarsButtonReleased;
    }
}
