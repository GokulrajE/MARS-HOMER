using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using static AppData;

public static class SessionDataHandler
{

    public static float[] moveTimeData;
    public static string[] dateData;
    public static string DATEFORMAT = "dd/MM";

    //SESSION FILE  HEADER FORMAT AND DATETIME FORMAT
    public static string DATEFORMAT_INFILE = "yyyy-MM-dd HH:mm:ss";
    public static string DATETIME = "DateTime";
    public static string MOVETIME = "moveTime";
    public static string STARTTIME = "StartTime";
    public static string STOPTIME = "StopTime";
    public static string MOVEMENT = "Movement";
    public static Dictionary<string, float> movementMoveTimePrev { get; private set; } // Previous movement time 
  
    
    //CALCULATE MOVETIME PER DAY FOR ALL MOVEMENTS
    public static  void MovTimePerDay()
    {
       
        var movTimePerDay = AppData.Instance.userData.dTableSession.AsEnumerable()
            .GroupBy(row => DateTime.ParseExact(row.Field<string>(DATETIME), DATEFORMAT_INFILE, CultureInfo.InvariantCulture).Date) // Group by date only
            .Select(group => new
            {
                Date = group.Key,
                DayOfWeek = group.Key.DayOfWeek,   // Get the day of the week
                TotalMovTime = group.Sum(row => Convert.ToInt32(row[MOVETIME]))
            })
            .ToList();
        moveTimeData = new float[movTimePerDay.Count];
        dateData = new string[movTimePerDay.Count];
       
        for (int i = 0; i < movTimePerDay.Count; i++)
        {
            moveTimeData[i] = movTimePerDay[i].TotalMovTime / 60f; // Convert seconds to minutes
           
            dateData[i] = movTimePerDay[i].Date.ToString(DATEFORMAT);       // Format date as "dd/MM"
           
        }
    }

    //CALCULATE MOVETIME PER DAY FOR SELECTED MOVEMENT
    public static void SelectedMovement(string movement)
    {
  
        var filteredData = AppData.Instance.userData.dTableSession.AsEnumerable()
            .Where(row => row.Field<string>(MOVEMENT) == movement)
            .Select(row => new
            {
                Date = DateTime.ParseExact(row.Field<string>(DATETIME), DATEFORMAT_INFILE , CultureInfo.InvariantCulture).Date,
                MovTime = Convert.ToDouble(row[MOVETIME])
            })
            .GroupBy(entry => entry.Date)
            .Select(group => new
            {
                Date = group.Key,
                TotalMovTime = group.Sum(entry => entry.MovTime) / 60.0 // Convert to minutes
            })
            .OrderBy(result => result.Date)
            .ToList();

        dateData = new string[filteredData.Count];
        moveTimeData = new float[filteredData.Count];

        for (int i = 0; i < filteredData.Count; i++)
        {
            dateData[i] = filteredData[i].Date.ToString(DATEFORMAT); // Format date as "dd/MM"
            moveTimeData[i] = (float)filteredData[i].TotalMovTime; // Store movement time in minutes
            
        }
    }

}
