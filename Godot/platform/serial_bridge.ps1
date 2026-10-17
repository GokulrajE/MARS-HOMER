param([Parameter(Mandatory=$true)][string]$PortName,
      [Parameter(Mandatory=$true)][int]$SocketPort,
      [Parameter(Mandatory=$true)][string]$Token)
$ErrorActionPreference = 'Stop'
$client = New-Object System.Net.Sockets.TcpClient
$serial = $null
try {
 $client.Connect('127.0.0.1', $SocketPort)
 $stream = $client.GetStream()
 $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))
 $writer.AutoFlush = $true
 $writer.WriteLine((@{token=$Token} | ConvertTo-Json -Compress))
 $serial = New-Object System.IO.Ports.SerialPort($PortName,115200,'None',8,'One')
 $serial.Handshake = 'None'
 $serial.DtrEnable = $true
 $serial.ReadTimeout = 250
 $serial.WriteTimeout = 250
 $serial.Open()
 $writer.WriteLine('{"connected":true}')
 $pending = ''
 $readBuffer = New-Object byte[] 4096
 while ($client.Connected) {
  if ($serial.BytesToRead -gt 0) {
   $amount = $serial.Read($readBuffer,0,[Math]::Min(4096,$serial.BytesToRead))
   $writer.WriteLine((@{bytes=[Convert]::ToBase64String($readBuffer,0,$amount)} | ConvertTo-Json -Compress))
  }
  if ($stream.DataAvailable) {
   $amount = $stream.Read($readBuffer,0,$readBuffer.Length)
   if ($amount -eq 0) { break }
   $pending += [Text.Encoding]::UTF8.GetString($readBuffer,0,$amount)
   while ($pending.Contains("`n")) {
    $end = $pending.IndexOf("`n")
    $message = $pending.Substring(0,$end) | ConvertFrom-Json
    $pending = $pending.Substring($end+1)
    if ($message.close) { return }
    if ($message.bytes) {
     $outputBytes = [Convert]::FromBase64String($message.bytes)
     $serial.Write($outputBytes,0,$outputBytes.Length)
    }
   }
   if ($pending.Length -gt 65536) { throw 'Invalid bridge message' }
  }
  if ($client.Client.Poll(0,[Net.Sockets.SelectMode]::SelectRead) -and $client.Available -eq 0) { break }
  Start-Sleep -Milliseconds 2
 }
} catch {
 Write-Error $_.Exception.Message -ErrorAction Continue
 if ($writer) { try { $writer.WriteLine((@{error=$_.Exception.Message} | ConvertTo-Json -Compress)) } catch {} }
} finally {
 if ($serial) { if ($serial.IsOpen) { $serial.Close() }; $serial.Dispose() }
 $client.Close()
}
