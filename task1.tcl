set opt(nn)         6       
set opt(seed)       10
set opt(stop)       50000
set opt(x)			500	
set opt(y)			500	
set opt(pro)        0.1
set ns      [new Simulator]
set opt(prop)		Propagation/TwoRayGround
set topo	[new Topography]
set prop	[new $opt(prop)]
$topo load_flatgrid $opt(x) $opt(y)
$prop topography $topo

# Opening Trace file
set tracefd     [open simple.tr w]
$ns trace-all $tracefd

set namfd [open out.nam w]
$ns namtrace-all $namfd

set simstart 0
set simend $opt(stop)


#Random variable
set rng [new RNG]
$rng seed $opt(seed)

set maxwnd 1000 ; 
set pktsize 1460 ; 
set filesize 500 ; 

# maximum number of tcps per class
set nof_tcps 100
set nof_senders 4

# the total (theoretical) load
set rho 0.8
set rho_cl [expr ($rho/$nof_senders)]
#flow interarrival time
set mean_intarrtime [expr ($pktsize+40)*8.0*$filesize/(11000000*$rho_cl)]

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


###########################################
# Routine performed for each completed file transfer
Agent/TCP instproc done {} {
    global ns freelist reslist ftp rng filesize mean_intarrtime nof_tcps \
        simstart simend delres nlist nof_senders

    #flow-ID of the TCP flow
    set flind [$self set fid_]

    #the class is determined by the flow-ID and total number of tcp-sources
    set sender [expr int(floor($flind/$nof_tcps))]
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
    if {$starttime >= $simstart && $tt < $simend} {
        lappend delres($sender) [expr $tt-$starttime]
    }
    if {$tt > $simend} {
        $ns at $tt "$ns halt"
    }
}


###########################################
# Routine performed for each new flow arrival
proc start_flow {sender timetostart} {
    global ns freelist reslist ftp tcp_s tcp_d rng nof_tcps filesize mean_intarrtime simend nof_senders mean_size
    set tt [$ns now]
    set freeflows [llength $freelist($sender)]
    set resflows [llength $reslist($sender)]
    lappend nlist($sender) [list $timetostart $resflows]
    if {$freeflows == 0} {
    }
    if {$freeflows != 0} {
        #take the first index from the list of free flows
        set ind [lindex $freelist($sender) 0]
        set cur_fsize [expr ceil([$rng exponential $filesize])]
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

for {set i 0} {$i < $opt(nn) } {incr i} {
    set node_($i) [$ns node]
}

#Sender/receivers location
set nn $opt(nn)

#Create links between the nodes
$ns duplex-link $node_(0) $node_(4) 100Mb 10ms DropTail
$ns duplex-link $node_(1) $node_(4) 100Mb 40ms DropTail
$ns duplex-link $node_(2) $node_(4) 100Mb 70ms DropTail
$ns duplex-link $node_(3) $node_(4) 100Mb 100ms DropTail

# Bottleneck Link between the nodes
$ns duplex-link $node_(4) $node_(5) 10Mb 10ms DropTail

$ns queue-limit $node_(0) $node_(4) 1000
$ns queue-limit $node_(1) $node_(4) 1000
$ns queue-limit $node_(2) $node_(4) 1000
$ns queue-limit $node_(3) $node_(4) 1000
$ns queue-limit $node_(4) $node_(5) 1000

set slink [$ns link $node_(4) $node_(5)]
set fmon [$ns makeflowmon Fid]
$ns attach-fmon $slink $fmon

# create a random variable that follows the uniform distribution
set loss_random_variable [new RandomVariable/Uniform]
$loss_random_variable set min_ 0 # the range of the random variable;
$loss_random_variable set max_ 100
set loss_module [new ErrorModel]
$loss_module drop-target [new Agent/Null]

$loss_module set rate_ $opt(pro)
$loss_module ranvar $loss_random_variable

$ns lossmodel $loss_module $node_(4) $node_(5)

for {set jj 0} {$jj < 100} {incr jj} {
    for {set ii 0} {$ii < $nn - 2} {incr ii} {
        set tcp [new Agent/TCP]
        $tcp set packetSize_ $pktsize
        $tcp set class_ 2
        $tcp set window_ $maxwnd
        $ns attach-agent $node_($ii) $tcp
        set sink [new Agent/TCPSink]
        $ns attach-agent $node_(5) $sink
        $ns connect $tcp $sink
        $tcp set fid_ [expr 100*$ii + $jj]
        lappend tcp_s($ii) $tcp
        lappend tcp_d($ii) $sink
        set ftp_local [new Application/FTP]
        $ftp_local attach-agent $tcp
        $ftp_local set type_ FTP
        lappend ftp($ii) $ftp_local
        lappend freelist($ii) $jj
    }
}

set parr_start 0 
set pdrops_start 0 
proc record_start {} { 
 global fmon ns parr_start pdrops_start nof_classes 
 #you have 
 set parr_start [$fmon set parrivals_] 
 set pdrops_start [$fmon set pdrops_] 
 puts "Bottleneck at [$ns now]: arr=$parr_start, drops=$pdrops_start" 
} 
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

record_start
$ns at 50 "[start_flow 0 10]"
$ns at 50 "[start_flow 1 10]"
$ns at 50 "[start_flow 2 10]"
$ns at 50 "[start_flow 3 10]"

proc finish {} {
    global ns namfd tracefd delres result
    record_end
    $ns flush-trace
    
    for {set j 0} {$j < 4} {incr j} {
        set sum 0.0
        for {set i 0} {$i < [llength $delres($j)]} {incr i} {
            set sum [expr $sum + [lindex $delres($j) $i]]
        }
        set sum [expr $sum/[llength $delres($j)]]
        puts "Average time for class $j is $sum"
        set var($j) $sum
        set ans [expr   [lindex $result($j) 0]/$sum]
        puts "Average throughput  of class $j is [expr $ans] Mb";
    }

    for {set j 0} {$j < 4} {incr j} {
        puts "Ratio of class $j and class 0 is [expr $var($j)/$var(0)]"
    }

    #Close the NAM trace file
    close $namfd
    close $tracefd
    #Execute NAM on the trace file
    exec nam out.nam &
    exit 0
}


# Call the finish procedure after end of simulation time
$ns at $simend "finish"
$ns run
