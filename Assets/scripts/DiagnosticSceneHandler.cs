using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using TMPro;
using UnityEngine;

using UnityEngine.UI;
using System.Linq;


public class DiagnosticSceneHandler : MonoBehaviour
{
    public TMP_Text dataDisplayText;
    public Dropdown ddLimbType;
    public Button btnCalibrate;

    private static string FLOAT_FORMAT = "+0.00;-0.00";

    void Start()
    {

         // Connect to the robot.
        ConnectToRobot.Connect(AppData.COMPort);

        // Initialize UI
        InitializeUI();
        // Attach callbacks
        AttachControlCallbacks();

        // Get device version.
        MarsComm.getVersion();
        MarsComm.startSensorStream();

    }

    private void Update()
    {
        // MARS heartbeat
        MarsComm.sendHeartbeat();

        // Display device data
        DisplayDeviceData();

        // Update UI.
        UpdateUI();
    }

    private void onNewMarsData()
    {
        Debug.Log("New MARS data received.");
    }

    private void onMarsButtonReleased()
    {
        // This method is called when the MARS button is released
        Debug.Log("MARS button released.");
    }

    private void onCalibButtonReleased()
    {
        // This method is called when the calibration button is released
        Debug.Log("Calibration button released.");
    }

    
    private void InitializeUI()
    {
        // Fill dropdown list
        ddLimbType.ClearOptions();
        ddLimbType.AddOptions(MarsComm.LIMBTEXT.ToList());
        // List<string> _ctrlList = MarsComm.CONTROLTYPETEXT.ToList();
        // ddControlSelect.AddOptions(_ctrlList.Take(_ctrlList.Count - 1).ToList());
        // // Clear panel selections.
        // tglCalibSelect.enabled = true;
        // tglCalibSelect.isOn = false;
        // tglControlSelect.enabled = true;
        // tglControlSelect.isOn = false;
    }

    public void AttachControlCallbacks()
    {
        // Dropdown value change.
        ddLimbType.onValueChanged.AddListener(delegate { OnLimbTypeChange(); });

        // Calibrate button click.
        btnCalibrate.onClick.AddListener(delegate {
            // Send calibration command to MARS.
            MarsComm.calibrate();
            Debug.Log("Calibration command sent.");
        });
        // // Toggle button
        // tglCalibSelect.onValueChanged.AddListener(delegate { OnCalibrationChange(); });
        // tglControlSelect.onValueChanged.AddListener(delegate { OnControlChange(); });
        // tglDataLog.onValueChanged.AddListener(delegate { OnDataLogChange(); });

        // // Dropdown value change.
        // ddControlSelect.onValueChanged.AddListener(delegate { OnControlModeChange(); });

        // // Slider value change.
        // sldrTarget.onValueChanged.AddListener(delegate { OnControlTargetChange(); });
        // sldrCtrlBound.onValueChanged.AddListener(delegate { OnControlBoundChange(); });
        // sldrCtrlGain.onValueChanged.AddListener(delegate { OnControlGainChange(); });

        // // Button click.
        // btnNextRandomTarget.onClick.AddListener(delegate { OnNextRandomTarget(); });

        // // AAN Demo Button click.
        // btnAANDemo.onClick.AddListener(delegate { OnAANDemoSceneLoad(); });

        // Listen to MARS's event
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        MarsComm.OnCalibButtonReleased += onCalibButtonReleased;
        MarsComm.OnNewMarsData += onNewMarsData;
    }

    public void UpdateUI()
    {
        // Check if MARS has been calibrated.
        btnCalibrate.enabled = (MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
            && (MarsComm.LIMBTYPE[ddLimbType.value] != "NOLIMB");
    }

    public void DisplayDeviceData()
    {
        // State text
        string runT = MarsComm.runTime.ToString("0.000").PadRight(15);
        string packNo = MarsComm.packetNumber.ToString().PadRight(8);
        string stateText = string.Join("\n", new string[] {
            $"Time          : {MarsComm.currentTime}",
            $"Dev ID        : {MarsComm.deviceId}",
            $"F/W Version   : {MarsComm.version}",
            $"Compile Date  : {MarsComm.compileDate}",
            "",
            $"Device Time   : {runT} | Packet Number: {packNo}",
            $"Status        : {MarsComm.OUTDATATYPE[MarsComm.status], -15} | Error : {MarsComm.errorString}",
            $"Limb          : {MarsComm.LIMBTYPE[MarsComm.limb], -15} | Calib : {MarsComm.CALIBRATION[MarsComm.calibration]}",
            $"Control       : {MarsComm.CONTROLTYPE[MarsComm.controlType]}",
            "",
            ""
        });

        string robotAngles = string.Join(" ", new string[] {
            MarsComm.angle1.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.angle2.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.angle3.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.angle4.ToString(FLOAT_FORMAT).PadRight(8),
        });
        string imuAngles = string.Join(" ", new string[] {
            MarsComm.imu1Angle.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.imu2Angle.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.imu3Angle.ToString(FLOAT_FORMAT).PadRight(8),
            MarsComm.imu4Angle.ToString(FLOAT_FORMAT).PadRight(8),
        });
        string sensorText = String.Join("\n", new string[] {
            $"Robot Angles  : {robotAngles}",
            $"IMU Angles    : {imuAngles}",
            $"Force         : {MarsComm.force.ToString(FLOAT_FORMAT)}",
            $"MARS Button   : {MarsComm.marButton}",
            $"CALIB Button  : {MarsComm.calibButton}"
        });

        dataDisplayText.text = stateText + sensorText;

    }

    /*
     * Callback functions.
     */
    private void OnLimbTypeChange()
    {
        // Set MARS limb type.
        MarsComm.setLimb(MarsComm.LIMBTYPE[ddLimbType.value]);
    }

    private void OnApplicationQuit()
    {
        Application.Quit();
        JediComm.Disconnect();
    }
}
