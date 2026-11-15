param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$webRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'web'))
$listener = $null
for ($testPort = 8080; $testPort -lt 8100; $testPort++) {
    try {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $testPort)
        $listener.Start()
        break
    } catch {
        if ($listener) { $listener.Stop() }
        $listener = $null
    }
}
if (-not $listener) { throw 'No local port is available (8080-8099).' }
$address = 'http://127.0.0.1:' + $testPort + '/'
Write-Host "Mission Arestemis: $address"
Write-Host 'Keep this window open while playing. Close it to stop the local server.'
if (-not $NoBrowser) { Start-Process $address }
$mime = @{
    '.html'='text/html; charset=utf-8'; '.js'='application/javascript';
    '.wasm'='application/wasm'; '.pck'='application/octet-stream';
    '.png'='image/png'; '.svg'='image/svg+xml'; '.json'='application/json';
    '.txt'='text/plain; charset=utf-8'
}
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 10000
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $first = $reader.ReadLine()
            if (-not $first) { continue }
            $request = $first.Split(' ')
            do { $headerLine = $reader.ReadLine() } while ($headerLine)
            $urlPath = [Uri]::UnescapeDataString(($request[1] -split '\?')[0])
            if ($urlPath -eq '/') { $urlPath = '/index.html' }
            $filePath = [IO.Path]::GetFullPath((Join-Path $webRoot $urlPath.TrimStart('/')))
            $allowed = $filePath.StartsWith($webRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
            if (-not $allowed -or -not [IO.File]::Exists($filePath)) {
                $response = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
                $stream.Write($response,0,$response.Length)
                continue
            }
            $type = $mime[[IO.Path]::GetExtension($filePath)]
            if (-not $type) { $type = 'application/octet-stream' }
            $length = ([IO.FileInfo]$filePath).Length
            $response = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $type`r`nContent-Length: $length`r`nCache-Control: no-store`r`nCross-Origin-Opener-Policy: same-origin`r`nCross-Origin-Embedder-Policy: require-corp`r`nConnection: close`r`n`r`n")
            $stream.Write($response,0,$response.Length)
            if ($request[0] -ne 'HEAD') {
                $file = [IO.File]::OpenRead($filePath)
                try { $file.CopyTo($stream) } finally { $file.Dispose() }
            }
        } catch {
            Write-Host ('Request ended: ' + $_.Exception.Message)
        } finally { $client.Dispose() }
    }
} finally { $listener.Stop() }
