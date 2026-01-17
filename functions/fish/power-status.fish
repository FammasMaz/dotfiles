function power-status --description "Check battery status and power-draining processes"
    # Colors
    set -l red (set_color red)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l cyan (set_color cyan)
    set -l bold (set_color --bold)
    set -l reset (set_color normal)

    # Battery info
    set -l batt_info (pmset -g batt | tail -1)
    set -l percentage (echo $batt_info | grep -oE '[0-9]+%' | head -1)
    set -l charging (echo $batt_info | grep -oE 'charging|discharging|charged')
    set -l remaining (echo $batt_info | grep -oE '[0-9]+:[0-9]+ remaining' | head -1)

    echo ""
    echo "$bold$cyan═══ Battery ═══$reset"

    # Color code battery percentage
    set -l pct_num (string replace '%' '' $percentage)
    if test "$pct_num" -lt 20
        echo "  Status: $red$percentage$reset"
    else if test "$pct_num" -lt 50
        echo "  Status: $yellow$percentage$reset"
    else
        echo "  Status: $green$percentage$reset"
    end

    switch $charging
        case charging
            echo "  State:  $green⚡ Charging$reset"
        case discharging
            echo "  State:  $yellow🔋 On Battery$reset"
        case charged
            echo "  State:  $green✓ Fully Charged$reset"
    end

    if test -n "$remaining"
        echo "  Time:   $remaining"
    end

    # Top CPU processes
    echo ""
    echo "$bold$cyan═══ Top CPU Processes ═══$reset"
    printf "  %-7s %-28s %s\n" "CPU%" "Process" "PID"
    echo "  ────── ──────────────────────────── ─────"

    ps -Ao pid,%cpu,comm -r | head -11 | tail -10 | while read -l pid cpu comm
        if test "$cpu" != "0.0" -a -n "$comm"
            set -l name (basename "$comm")
            if test (string length "$name") -gt 28
                set name (string sub -l 25 "$name")"..."
            end

            set -l cpu_num (printf "%.0f" $cpu 2>/dev/null; or echo 0)
            if test "$cpu_num" -ge 20
                printf "  $red%-7s$reset %-28s %s\n" "$cpu%" "$name" "$pid"
            else if test "$cpu_num" -ge 10
                printf "  $yellow%-7s$reset %-28s %s\n" "$cpu%" "$name" "$pid"
            else
                printf "  %-7s %-28s %s\n" "$cpu%" "$name" "$pid"
            end
        end
    end

    # Power assertions (things preventing sleep)
    echo ""
    echo "$bold$cyan═══ Power Assertions ═══$reset"

    set -l problem_found 0
    pmset -g assertions 2>/dev/null | grep "pid" | grep -v "powerd" | grep -v "caffeinate" | while read -l line
        set problem_found 1
        set -l app (echo $line | grep -oE '\([^)]+\)' | head -1 | tr -d '()')
        set -l reason (echo $line | grep -oE 'named: "[^"]+"' | sed 's/named: "//' | sed 's/"$//')
        if test -n "$app"
            echo "  $red⚠$reset $yellow$app$reset: $reason"
        end
    end

    if test $problem_found -eq 0
        echo "  $green✓ No problematic assertions$reset"
    end

    # Battery health - use AppleRawMaxCapacity for accurate health calculation
    echo ""
    echo "$bold$cyan═══ Battery Health ═══$reset"
    set -l cycles (ioreg -r -c AppleSmartBattery 2>/dev/null | grep '"CycleCount" =' | head -1 | awk '{print $NF}')
    set -l raw_max (ioreg -r -c AppleSmartBattery 2>/dev/null | grep '"AppleRawMaxCapacity" =' | head -1 | awk '{print $NF}')
    set -l design_cap (ioreg -r -c AppleSmartBattery 2>/dev/null | grep '"DesignCapacity" =' | head -1 | awk '{print $NF}')

    echo "  Cycle Count: $cycles"

    if test -n "$raw_max" -a -n "$design_cap"
        if test "$design_cap" -gt 0 2>/dev/null
            set -l health_pct (math "round($raw_max / $design_cap * 100)")
            if test "$health_pct" -ge 80
                echo "  Health: $green$health_pct%$reset"
            else if test "$health_pct" -ge 60
                echo "  Health: $yellow$health_pct%$reset"
            else
                echo "  Health: $red$health_pct%$reset"
            end
        end
    end

    echo ""
end
