# ======================================================================
# 802.11 Script Options
# ======================================================================
set opt(chan)		Channel/WirelessChannel
set opt(prop)		Propagation/TwoRayGround
set opt(netif)		Phy/WirelessPhy
set opt(mac)		Mac/802_11
set opt(ifq)		Queue/DropTail/PriQueue
set opt(ll)			LL
set opt(ant)      Antenna/OmniAntenna
set opt(x)			500	;# X dimension of the topography
set opt(y)			500	;# Y dimension of the topography
set opt(ifqlen)	500	;# max packet in ifq
set opt(nn)			5		;# number of nodes
set opt(seed)		10
set opt(stop)		2000.0		;# simulation time
set opt(rp)       DSDV        ;# routing protocol
# ======================================================================
set simstart 10
set simend $opt(stop)

set bw 11Mb
Mac/802_11 set dataRate_ $bw
Mac/802_11 set RTSThreshold_ 3000

proc create-god { nodes } {
	global ns_ god_
	set god_ [new God]
	$god_ num_nodes $nodes
}

if { $opt(x) == 0 || $opt(y) == 0 } {
	puts "Invalid Topology parameters"
	exit 1
}

#Random variable
set rng [new RNG]
$rng seed $opt(seed)

set maxwnd 1000 ; # TCP Window Size
set pktsize 1460 ; # Pkt size in bytes (1500 - IP header - TCP header)
set filesize 400 ; #As count of packets

#maximum number of tcps per class
set nof_tcps 100
set nof_senders 4 

# the total (theoretical) load
set rho 0.3
set rho_cl [expr ($rho/$nof_senders)]
#flow interarrival time
set mean_intarrtime [expr ($pktsize+40)*8.0*$filesize/(11000000*$rho_cl)]
puts "1/la = $mean_intarrtime"

for {set ii 0} {$ii < $nof_senders} {incr ii} {
  #contains the delay results for each class
  set delres($ii) {}
  #contains the number of active flows as a function of time
  set nlist($ii) {}
  #contains the free flows
  set freelist($ii) {}
  #contains information of the reserved flows
  set reslist($ii) {}
}


###########################################
# Routine performed for each completed file transfer
Agent/TCP instproc done {} {
    global ns freelist reslist ftp rng filesize mean_intarrtime nof_tcps \
		simstart simend delres nlist tmplog nof_senders
 
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
  if {$starttime > $simstart && $tt < $simend} {
    lappend delres($sender) [expr $tt-$starttime]
  }

  if {$tt > $simend} {
	$ns at $tt "$ns halt"
  }
}


###########################################
# Routine performed for each new flow arrival
proc start_flow {sender} {
  global ns freelist reslist ftp tcp_s tcp_d rng nof_tcps filesize mean_intarrtime simend tmplog nof_senders
  #you have to create the variables tcp_s (tcp source) and tcp_d (tcp destination)
  
  set tt [$ns now]
  set freeflows [llength $freelist($sender)]
  set resflows [llength $reslist($sender)]
  
  lappend nlist($sender) [list $tt $resflows]
  
  if {$freeflows == 0} {
    puts "Sender $sender: At $tt, nof of free TCP sources == 0!!!"  
    exit
  }
  #take the first index from the list of free flows
  set ind [lindex $freelist($sender) 0]
  set cur_fsize [expr ceil([$rng exponential $filesize])]
  
  $tcp_s($sender,$ind) reset
  $tcp_d($sender,$ind) reset
  $ftp($sender,$ind) produce $cur_fsize
  
  set freelist($sender) [lreplace $freelist($sender) 0 0]
  lappend reslist($sender) [list $ind $tt $cur_fsize]
  
  set newarrtime [expr $tt+[$rng exponential $mean_intarrtime]]
  $ns at $newarrtime "start_flow $sender"
  
  if {$tt > $simend} {
	$ns at $tt "$ns halt"
  }
}

#Initializing a simulator instance
set ns		[new Simulator]
set chan	[new $opt(chan)]
set prop	[new $opt(prop)]
set topo	[new Topography]

$topo load_flatgrid $opt(x) $opt(y)
$prop topography $topo

# Create God
create-god $opt(nn)

# Opening Trace file
set tracefd     [open simple.tr w]
$ns trace-all $tracefd

# configure node
$ns node-config  -adhocRouting $opt(rp) \
                  -llType $opt(ll) \
                  -macType $opt(mac) \
                  -ifqType $opt(ifq) \
                  -ifqLen $opt(ifqlen) \
                  -antType $opt(ant) \
                  -propType $opt(prop) \
                  -phyType $opt(netif) \
                  -channel $chan \
                  -topoInstance $topo

for {set i 0} {$i < $opt(nn) } {incr i} {
         set node_($i) [$ns node]
}

#Sender/receivers location
$node_(0) set X_ 100.0
$node_(0) set Y_ 100.0
$node_(0) set Z_ 0.0

$node_(1) set X_ 100.0
$node_(1) set Y_ 100.0
$node_(1) set Z_ 0.0

$node_(2) set X_ 100.0
$node_(2) set Y_ 100.0
$node_(2) set Z_ 0.0

$node_(3) set X_ 100.0
$node_(3) set Y_ 100.0
$node_(3) set Z_ 0.0

$node_(4) set X_ 0.0
$node_(4) set Y_ 0.0
$node_(4) set Z_ 0.0

############# Add your code from here ################

# create all TCP flows
# - attach them to access nodes
# - configure the parameters (flow id, packet size)
# - flow numbering assumed to be the following
#   - class 1 id's: 0...nof_tcps-1
#   - class 2 id's: nof_tcps...(2*nof_tcps)-1, etc.
# - create an FTP application on top of each TCP
# - remember to insert each new connection in freelist
#
# - Schedule the first flow arrivals for each class
#
# and Finally process the collected result