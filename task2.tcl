set opt(nn)         6   ;# number of nodes
set opt(seed)       10
set opt(stop)       5000        ;# simulation time
set ns      [new Simulator]
set count 1;

# Opening Trace file
set tracefd     [open simple.tr w]
$ns trace-all $tracefd

set namfd [open out.nam w]
$ns namtrace-all $namfd

set simstart 10
set simend $opt(stop)


#Random variable
set rng [new RNG]
$rng seed $opt(seed)

set maxwnd 1000 ; # TCP Window Size
set pktsize 1460 ; # Pkt size in bytes (1500 - IP header - TCP header)
set filesize 500 ; #As count of packets

# maximum number of tcps per class
set nof_tcps 300
set nof_senders 4

# the total (theoretical) load
set rho 0.9
set rho_cl [expr ($rho/$nof_senders)]
#flow interarrival time
set mean_intarrtime [expr ($pktsize+40)*8.0*$filesize/(11000000*$rho_cl)]
# puts "1/la = $mean_intarrtime"

for {set ii 0} {$ii < $nof_senders} {incr ii} {
    #contains the delay results for each class
    set delres($ii) {}
    #contains the number of active flows as a function of time
    set nlist($ii) {}
    #contains the free flows
    set freelist($ii) {}
    #contains information of the reserved flows
    set reslist($ii) {}
    set tcp_s($ii) {}
    set tcp_d($ii) {}
    set mean_size($ii) {}
    set result($ii) {}

}

Agent/TCP instproc done {} {
    global ns freelist reslist ftp rng filesize mean_intarrtime nof_tcps simstart simend delres nlist nof_senders

    set flind [$self set fid_]

    set sender [expr int(floor($flind/($nof_tcps)))]
    set ind [expr $flind-$sender*$nof_tcps]

    lappend nlist($sender) [list [$ns now] [llength $reslist($sender)]]

    for {set nn 0} {$nn < [llength $reslist($sender)]} {incr nn} {
        set tmp [lindex $reslist($sender) $nn]
        set tmpind [lindex $tmp 0]
        if {$tmpind == $ind} {
            set mm $nn
            set starttime [lindex $tmp 1]
        }
    }

    set reslist($sender) [lreplace $reslist($sender) $mm $mm]
    lappend freelist($sender) $ind

    set tt [$ns now]
    if {$starttime > $simstart && $tt < $simend} {
        lappend delres($sender) [expr $tt-$starttime]
    }
    if {$tt > $simend} {
        $ns at $tt "$ns halt"
    }
}


proc start_flow {sender timetostart} {

    global ns freelist reslist ftp tcp_s tcp_d rng nof_tcps filesize mean_intarrtime simend nof_senders mean_size
    set tt [$ns now]
    set freeflows [llength $freelist($sender)]
    set resflows [llength $reslist($sender)]
    lappend nlist($sender) [list $tt $resflows]

    if {$freeflows == 0} {
        # puts "Sender $sender: At $timetostart, nof of free TCP sources == 0!!!"
    }
    if {$freeflows != 0} {
        set ind [lindex $freelist($sender) 0]
        set cur_fsize [expr ceil([$rng exponential $filesize])]
        # puts "$cur_fsize"
        lappend mean_size($sender) $cur_fsize

        [lindex $tcp_s($sender) $ind] reset
        [lindex $tcp_d($sender) $ind] reset
        $ns at $timetostart "[lindex $ftp($sender) $ind] produce $cur_fsize"

        set freelist($sender) [lreplace $freelist($sender) 0 0]
        lappend reslist($sender) [list $ind $timetostart $cur_fsize]

        set newarrtime [expr $timetostart+[$rng exponential $mean_intarrtime]]

        $ns at $newarrtime "[start_flow $sender $newarrtime]"

        if {$tt > $simend} {
            $ns at $tt "$ns halt"
        }
    }
}

set endnodes 24
for {set i 0} {$i <$endnodes } {incr i} {
    set endnode_($i) [$ns node]
}

set corenodes 8

for {set i 0} {$i <$corenodes } {incr i} {
    set corenode_($i) [$ns node]
}

set bootlenecks 2

for {set i 0} {$i <$bootlenecks} {incr i} {
    set bottlenck_($i) [$ns node]
}


#Sender/receivers location
set nn $opt(nn)
#Create links between the nodes
for {set i 0} {$i <$corenodes } {incr i} {
  $ns duplex-link $corenode_($i) $endnode_([expr $i*3])  10Mb 10ms DropTail
  $ns duplex-link $corenode_($i) $endnode_([expr 3*$i+1]) 10Mb 10ms DropTail
  $ns duplex-link $corenode_($i) $endnode_([expr 3*$i+2]) 10Mb 10ms DropTail  
}

$ns duplex-link $corenode_(0) $bottlenck_(0) 100Mb 5ms DropTail
$ns duplex-link $corenode_(1) $bottlenck_(0) 100Mb 20ms DropTail
$ns duplex-link $corenode_(2) $bottlenck_(0) 100Mb 35ms DropTail
$ns duplex-link $corenode_(3) $bottlenck_(0) 100Mb 50ms DropTail
$ns duplex-link $corenode_(4) $bottlenck_(1) 100Mb 5ms DropTail
$ns duplex-link $corenode_(5) $bottlenck_(1) 100Mb 20ms DropTail
$ns duplex-link $corenode_(6) $bottlenck_(1) 100Mb 35ms DropTail
$ns duplex-link $corenode_(7) $bottlenck_(1) 100Mb 50ms DropTail


$ns duplex-link $bottlenck_(1) $bottlenck_(0) 10Mb 30ms DropTail



$ns queue-limit $endnode_(0) $corenode_(0) 100
$ns queue-limit $endnode_(1) $corenode_(0) 100
$ns queue-limit $endnode_(2) $corenode_(0) 100
$ns queue-limit $endnode_(3) $corenode_(1) 100
$ns queue-limit $endnode_(4) $corenode_(1) 100
$ns queue-limit $endnode_(5) $corenode_(1) 100
$ns queue-limit $endnode_(6) $corenode_(2) 100
$ns queue-limit $endnode_(7) $corenode_(2) 100
$ns queue-limit $endnode_(8) $corenode_(2) 100
$ns queue-limit $endnode_(9) $corenode_(3) 100
$ns queue-limit $endnode_(10) $corenode_(3) 100
$ns queue-limit $endnode_(11) $corenode_(3) 100
$ns queue-limit $endnode_(12) $corenode_(4) 100
$ns queue-limit $endnode_(13) $corenode_(4) 100
$ns queue-limit $endnode_(14) $corenode_(4) 100
$ns queue-limit $endnode_(15) $corenode_(5) 100
$ns queue-limit $endnode_(16) $corenode_(5) 100
$ns queue-limit $endnode_(17) $corenode_(5) 100
$ns queue-limit $endnode_(18) $corenode_(6) 100
$ns queue-limit $endnode_(19) $corenode_(6) 100
$ns queue-limit $endnode_(20) $corenode_(6) 100
$ns queue-limit $endnode_(21) $corenode_(7) 100
$ns queue-limit $endnode_(22) $corenode_(7) 100
$ns queue-limit $endnode_(23) $corenode_(7) 100
$ns queue-limit $bottlenck_(1) $bottlenck_(0) 100

set slink [$ns link $bottlenck_(1) $bottlenck_(0)]
set fmon [$ns makeflowmon Fid]
$ns attach-fmon $slink $fmon

for {set ii 0} {$ii < 4} {incr ii} {
    for {set kk 0} {$kk < 3} {incr kk} {
        for {set jj 0} {$jj < 100} {incr jj} {
        set tcp [new Agent/TCP]
        $tcp set packetSize_ $pktsize
        $tcp set class_ 2
        $tcp set window_ $maxwnd
        $ns attach-agent $endnode_([expr $ii*3+$kk]) $tcp
        set sink [new Agent/TCPSink]
        set tmp [expr $ii*3+$kk+12]
        $ns attach-agent $endnode_($tmp) $sink
        $ns connect $tcp $sink
        $tcp set fid_ [expr 300*($ii)+100*($kk) +  $jj]

        lappend tcp_s($ii) $tcp
        lappend tcp_d($ii) $sink
        set ftp_local [new Application/FTP]
        $ftp_local attach-agent $tcp
        $ftp_local set type_ FTP
        lappend ftp($ii) $ftp_local
        lappend freelist($ii) [expr 100*$kk +  $jj]
      }
    }
}

set parr_start 0 
set pdrops_start 0 
proc record_start {} { 
 global fmon ns parr_start pdrops_start nof_classes 
 set parr_start [$fmon set parrivals_] 
 set pdrops_start [$fmon set pdrops_] 
 puts "Bottleneck at [$ns now]: arr=$parr_start, drops=$pdrops_start" 
} 


record_start
$ns at 0 "[start_flow 0 0]"
$ns at 0 "[start_flow 1 0]"
$ns at 0 "[start_flow 2 0]"
$ns at 0 "[start_flow 3 0]"

set parr_end 0 
set pdrops_end 0 
proc record_end { } { 
  global fmon ns parr_start pdrops_start nof_classes simend mean_size delres result
  set parr_start [$fmon set parrivals_] 
  set pdrops_start [$fmon set pdrops_] 
  puts "Bottleneck at [$ns now]: arr=$parr_start, drops=$pdrops_start" 
 for {set ii 0} {$ii < 4} {incr ii} {
      set sum 0.0
      for {set jj 0} {$jj < [llength $mean_size($ii)]} {incr jj} {
          set sum [expr $sum + [lindex $mean_size($ii) $jj]]
        }
      set sum [expr $sum/[llength $mean_size($ii)]];
      lappend result($ii) [expr $sum*1500*8/1000000]
    #   puts "Mean size of file for the class $ii is $sum " 
}
}

proc finish {} {
    global ns namfd tracefd parr_start pdrops_start fmon  delres mean_size delres result
    record_end

      for {set j 0} {$j < 4} {incr j} {
        set sum 0.0
        for {set i 0} {$i < [llength $delres($j)]} {incr i} {
            set sum [expr $sum + [lindex $delres($j) $i]]
        }
        set sum [expr $sum/[llength $delres($j)]]
        puts "Average time for class t is $sum"
        set var($j) $sum
        set k [lindex $result($j) 0];
        set ans [expr   $k/$sum]
        puts "Average throughput  of class $j is [expr $ans] Mb";
    }

    for {set j 0} {$j < 4} {incr j} {
        puts "Ratio of class $j and class 0 is [expr $var($j)/$var(0)]"
    }
    $ns flush-trace

    close $namfd
    close $tracefd

    exec nam out.nam &
    exit 0
}
# Call the finish procedure after end of simulation time
$ns at $simend "finish"
$ns run