
# ============================================================
# NOVATION LAUNCHPAD MK1 - FIVE-SEQUENCE LIGHT SHOW
# Windows 11 | PowerShell | No Python or extra MIDI libraries
#
# Animation tick: 25 ms
# Sequence duration: 18 seconds
# MIDI output is rate-limited to protect the original MK1.
# Press Ctrl+C to stop.
# ============================================================

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class LaunchpadMidi {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct Caps {
        public ushort mid;
        public ushort pid;
        public uint version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string name;
        public ushort technology;
        public ushort voices;
        public ushort notes;
        public ushort channels;
        public uint support;
    }

    [DllImport("winmm.dll")]
    public static extern uint midiOutGetNumDevs();

    [DllImport("winmm.dll", CharSet=CharSet.Unicode)]
    public static extern uint midiOutGetDevCapsW(
        UIntPtr id, out Caps caps, uint size);

    [DllImport("winmm.dll")]
    static extern uint midiOutOpen(
        out IntPtr handle, uint id, IntPtr callback,
        IntPtr instance, uint flags);

    [DllImport("winmm.dll")]
    static extern uint midiOutShortMsg(IntPtr handle, uint message);

    [DllImport("winmm.dll")]
    static extern uint midiOutClose(IntPtr handle);

    public static string GetName(int id) {
        Caps c;
        uint r = midiOutGetDevCapsW(
            new UIntPtr((uint)id), out c,
            (uint)Marshal.SizeOf(typeof(Caps)));
        return r == 0 ? c.name : "";
    }

    public static IntPtr Open(int id) {
        IntPtr h;
        uint r = midiOutOpen(out h, (uint)id,
            IntPtr.Zero, IntPtr.Zero, 0);
        if (r != 0)
            throw new Exception("MIDI output open failed: " + r);
        return h;
    }

    public static void Send(IntPtr h, int status, int d1, int d2) {
        uint msg = (uint)(status | (d1 << 8) | (d2 << 16));
        uint r = midiOutShortMsg(h, msg);
        if (r != 0)
            throw new Exception("MIDI output error: " + r);
    }

    public static void Close(IntPtr h) {
        midiOutClose(h);
    }
}
"@

# MK1 colour values
$OFF      = 0
$RED      = 15
$GREEN    = 60
$AMBER    = 63
$DIMRED   = 13
$DIMGREEN = 28
$DIMAMBER = 29

# Animation settings
$frameDelayMs = 25
$framesPerSequence = 720       # 18 seconds at 25 ms
$messagesPerFrame = 8           # 320 MIDI messages/second maximum

$handle = [IntPtr]::Zero

try {
    Write-Host ""
    Write-Host "LAUNCHPAD MK1 LIGHT SHOW" -ForegroundColor Cyan
    Write-Host "Searching for MIDI outputs..."

    $deviceCount = [LaunchpadMidi]::midiOutGetNumDevs()

    if ($deviceCount -eq 0) {
        throw "No MIDI outputs found. Connect your Launchpad."
    }

    $matchingDevices = @()

    for ($i = 0; $i -lt $deviceCount; $i++) {
        $name = [LaunchpadMidi]::GetName($i)
        Write-Host "[$i] $name"

        if ($name -match "Launchpad") {
            $matchingDevices += $i
        }
    }

    if ($matchingDevices.Count -eq 1) {
        $device = [int]$matchingDevices[0]
    }
    else {
        $answer = Read-Host "Enter Launchpad MIDI OUTPUT number"
        $device = 0

        if (-not [int]::TryParse($answer, [ref]$device) -or
            $device -lt 0 -or $device -ge $deviceCount) {
            throw "Invalid MIDI output number."
        }
    }

    $handle = [LaunchpadMidi]::Open($device)

    # Address all 80 LEDs.
    # Grid: MIDI notes 0,1...7,16...119.
    # Right buttons: note column 8.
    # Top buttons: MIDI CC 104-111.
    $ledKeys = @()

    for ($y = 0; $y -lt 8; $y++) {
        for ($x = 0; $x -lt 8; $x++) {
            $ledKeys += "G:" + (($y * 16) + $x)
        }
    }

    for ($y = 0; $y -lt 8; $y++) {
        $ledKeys += "R:" + (($y * 16) + 8)
    }

    for ($x = 0; $x -lt 8; $x++) {
        $ledKeys += "T:" + $x
    }

    $desired = @{}
    $random = [System.Random]::new()
    $frame = 0

    $sequenceNames = @(
        "FULL COLOUR WAVE",
        "CHECKERBOARD CHASE",
        "EXPANDING DIAMOND",
        "SPARKLE STORM",
        "TRAIL CHASE"
    )

    Write-Host ""
    Write-Host "Animation interval: 25 ms"
    Write-Host "Sequence duration: 18 seconds"
    Write-Host "Five animations. Press Ctrl+C to stop."
    Write-Host ""

    while ($true) {
        $mode = [int](($frame / $framesPerSequence) % 5)
        $step = $frame % $framesPerSequence

        if ($step -eq 0) {
            Write-Host ("Sequence: " + $sequenceNames[$mode]) `
                -ForegroundColor Cyan
        }

        # ----------------------------------------------------
        # MAIN 8 x 8 GRID
        # ----------------------------------------------------
        for ($y = 0; $y -lt 8; $y++) {
            for ($x = 0; $x -lt 8; $x++) {
                $colour = $OFF

                switch ($mode) {
                    0 {
                        # Existing: dense diagonal colour wave
                        $v = ($x + $y + [int]($step / 2)) % 12

                        if ($v -lt 4) {
                            $colour = $RED
                        }
                        elseif ($v -lt 8) {
                            $colour = $AMBER
                        }
                        else {
                            $colour = $GREEN
                        }

                        if ((($x - $y + $step) % 8) -eq 0) {
                            $colour = $AMBER
                        }
                    }

                    1 {
                        # Existing: moving checkerboard
                        $v = ($x + $y + [int]($step / 2)) % 2

                        if ($v -eq 0) {
                            $colour = $RED
                        }
                        else {
                            $colour = $GREEN
                        }

                        if ((($x + $step) % 4) -lt 2) {
                            $colour = $AMBER
                        }
                    }

                    2 {
                        # CONTINUOUS EXPANDING MULTICOLOUR DIAMOND
                        # No top-down wipe and no solid fill.
                        # The diamond expands from the centre, disappears
                        # at the edge, then starts again.

                        $distance = [Math]::Abs($x - 3.5) +
                                    [Math]::Abs($y - 3.5)

                        # Expand smoothly from centre to outer edge.
                        $radius = ($step % 64) / 4.0

                        # Keep a thin, clearly defined diamond outline.
                        $edgeDistance = [Math]::Abs($distance - $radius)

                        if ($edgeDistance -lt 0.55) {
                            # Main outline cycles through red, orange, green.
                            $colourPhase = (
                                [int]($radius * 2) +
                                [int]($step / 3)
                            ) % 3

                            switch ($colourPhase) {
                                0 { $colour = $GREEN }
                                1 { $colour = $AMBER }
                                2 { $colour = $RED }
                            }
                        }
                        elseif ($edgeDistance -lt 1.2) {
                            # Dim halo immediately around the outline.
                            $haloPhase = ([int]($radius * 2)) % 3

                            switch ($haloPhase) {
                                0 { $colour = $DIMGREEN }
                                1 { $colour = $DIMAMBER }
                                2 { $colour = $DIMRED }
                            }
                        }
                        else {
                            # Leave the rest blank instead of wiping/filling.
                            $colour = $OFF
                        }
                    }

                    3 {
                        # Existing: dense sparkle storm
                        $colour = $DIMGREEN

                        if ((($x + $y + [int]($step / 2)) % 4) -eq 0) {
                            $colour = $GREEN
                        }

                        if ($random.Next(100) -lt 28) {
                            $colour = @($RED, $GREEN, $AMBER)[
                                $random.Next(3)]
                        }
                    }

                    4 {
                        # NEW: serpentine trail chase
                        # The head moves across each row, then reverses
                        # direction on the next row.
                        $pathIndex = $y * 8

                        if (($y % 2) -eq 0) {
                            $pathIndex += $x
                        }
                        else {
                            $pathIndex += (7 - $x)
                        }

                        $head = [int](($step / 2) % 64)
                        $distance = ($head - $pathIndex + 64) % 64

                        if ($distance -eq 0) {
                            # Bright head
                            $colour = $AMBER
                        }
                        elseif ($distance -le 2) {
                            $colour = $GREEN
                        }
                        elseif ($distance -le 5) {
                            $colour = $RED
                        }
                        elseif ($distance -le 9) {
                            $colour = $DIMAMBER
                        }
                        elseif ($distance -le 13) {
                            $colour = $DIMRED
                        }
                        else {
                            $colour = $OFF
                        }
                    }
                }

                $note = ($y * 16) + $x
                $desired["G:$note"] = $colour
            }
        }

        # ----------------------------------------------------
        # RIGHT-HAND ROUND BUTTONS
        # Separate moving red/amber/green chase.
        # ----------------------------------------------------
        for ($y = 0; $y -lt 8; $y++) {
            $v = ($y + [int]($frame / 2)) % 3

            if ($v -eq 0) {
                $colour = $RED
            }
            elseif ($v -eq 1) {
                $colour = $AMBER
            }
            else {
                $colour = $GREEN
            }

            # During the trail chase, accent the moving head.
            if ($mode -eq 4 -and
                $y -eq [int](($step / 2) % 8)) {
                $colour = $AMBER
            }

            $note = ($y * 16) + 8
            $desired["R:$note"] = $colour
        }

        # ----------------------------------------------------
        # TOP ROUND BUTTONS
        # Independent left-to-right colour sequence.
        # ----------------------------------------------------
        for ($x = 0; $x -lt 8; $x++) {
            $v = ($x + [int]($frame / 3)) % 3

            if ($v -eq 0) {
                $colour = $GREEN
            }
            elseif ($v -eq 1) {
                $colour = $RED
            }
            else {
                $colour = $AMBER
            }

            # Top buttons brighten in order during the trail.
            if ($mode -eq 4 -and
                $x -eq [int](($step / 2) % 8)) {
                $colour = $AMBER
            }

            $desired["T:$x"] = $colour
        }

        # ----------------------------------------------------
        # RATE-LIMITED MIDI OUTPUT
        # 8 messages every 25 ms = up to 320 messages/second.
        # Rotate across the 80 LEDs to distribute updates.
        # ----------------------------------------------------
        $start = ($frame * $messagesPerFrame) % $ledKeys.Count

        for ($i = 0; $i -lt $messagesPerFrame; $i++) {
            $index = ($start + $i) % $ledKeys.Count
            $key = $ledKeys[$index]
            $parts = $key.Split(":")
            $colour = [int]$desired[$key]

            if ($parts[0] -eq "G" -or $parts[0] -eq "R") {
                [LaunchpadMidi]::Send(
                    $handle, 0x90, [int]$parts[1], $colour
                )
            }
            else {
                [LaunchpadMidi]::Send(
                    $handle, 0xB0, (104 + [int]$parts[1]), $colour
                )
            }
        }

        $frame++
        Start-Sleep -Milliseconds $frameDelayMs
    }
}
finally {
    if ($handle -ne [IntPtr]::Zero) {
        Write-Host "`nStopping and clearing LEDs..." -ForegroundColor Yellow

        try {
            for ($y = 0; $y -lt 8; $y++) {
                for ($x = 0; $x -lt 8; $x++) {
                    [LaunchpadMidi]::Send(
                        $handle, 0x90, (($y * 16) + $x), 0
                    )
                }

                [LaunchpadMidi]::Send(
                    $handle, 0x90, (($y * 16) + 8), 0
                )
            }

            for ($x = 0; $x -lt 8; $x++) {
                [LaunchpadMidi]::Send(
                    $handle, 0xB0, (104 + $x), 0
                )
            }
        }
        catch {
            Write-Host "Some LEDs may need resetting."
        }

        [LaunchpadMidi]::Close($handle)
    }

    Write-Host "Light show stopped."
}
