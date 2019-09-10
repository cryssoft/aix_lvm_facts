#
#  FACT(S):     aix_vgs
#
#  PURPOSE:     This custom fact returns a hash of information about the volume
#		groups on the local machine.
#
#  RETURNS:     (hash)
#
#  AUTHOR:      Chris Petersen, Crystallized Software
#
#  DATE:        August 8, 2019
#
#  NOTES:       Myriad names and acronyms are trademarked or copyrighted by IBM
#               including but not limited to IBM, PowerHA, AIX, RSCT (Reliable,
#               Scalable Cluster Technology), and CAA (Cluster-Aware AIX).  All
#               rights to such names and acronyms belong with their owner.
#
#-------------------------------------------------------------------------------
#
#  LAST MOD:    (never)
#
#  MODIFICATION HISTORY:
#
#	(none)
#
#-------------------------------------------------------------------------------
#
Facter.add(:aix_vgs) do
    #  This only applies to the AIX operating system
    confine :osfamily => 'AIX'

    #  
    setcode do
        #  Define the hash and three arrays we'll need
        l_aixVgHash      = {}
        #
        l_aixVgTotal     = []
        l_aixVgVariedOff = []
        l_aixVgVariedOn  = []

        #  Grab the list of known volume groups (regardless of status)
        l_lines = Facter::Util::Resolution.exec('/usr/sbin/lsvg -L 2>/dev/null')
        l_lines && l_lines.split("\n").each do |l_oneLine|
            l_aixVgTotal.push(l_oneLine.strip())
        end

        #  Grab the list of volume groups that are varied on (one way or another)
        l_lines = Facter::Util::Resolution.exec('/usr/sbin/lsvg -L -o 2>/dev/null')
        l_lines && l_lines.split("\n").each do |l_oneLine|
            l_aixVgVariedOn.push(l_oneLine.strip())
        end

        #  Difference the lists to get a list of volumes that are varied off
        l_aixVgVariedOff = l_aixVgTotal - l_aixVgVariedOn

        #  Process the two lists - just mark the ones that are varied off, 
        #  query about the ones that are varied on
        #
        #  VARIED OFF - JUST THE FLAG
        #
        l_aixVgVariedOff.each do |l_vg|
            l_aixVgHash[l_vg]              = {}
            l_aixVgHash[l_vg]['varied_on'] = 'false'
        end
        #
        #  VARIED ON - A WHOLE LOT MORE
        #
        l_aixVgVariedOn.each do |l_vg|
            l_aixVgHash[l_vg]              = {}
            l_aixVgHash[l_vg]['varied_on'] = 'true'
            l_aixVgHash[l_vg]['lvs']       = []
            l_aixVgHash[l_vg]['pvs']       = []
            #  Add to the simple list of logical volumes in this VG in a way that matches the keys of $::facts['partition']
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/lsvg -L -l #{l_vg} 2>/dev/null")
            l_state = 0		#  Trivial FSM/DFA to ignore the headings
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split(' ')
                if l_state == 0
                    if l_list[0] == 'LV'
                        l_state = 1
                    end
                else
                    l_aixVgHash[l_vg]['lvs'].push('/dev/' + l_list[0])
                end
            end
            #  Add to the simple list of physical volumes in this VG in a way that matches the keys of $::facts['disks']
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/lsvg -L -p #{l_vg} 2>/dev/null")
            l_state = 0		#  Trivial FSM/DFA to ignore the headings
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split(' ')
                if l_state == 0
                    if l_list[0] == 'PV_NAME'
                        l_state = 1
                    end
                else
                    l_aixVgHash[l_vg]['pvs'].push(l_list[0])
                end
            end
            #  Well, this seems a bit of a kludge, but it's all I've found documented
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/readvgda #{l_aixVgHash[l_vg]['pvs'][0]} 2>/dev/null")
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split(' ')
                if l_list[1] == 'readvgda_type:'
                    l_aixVgHash[l_vg]['vgtype']=l_list.slice(2..-1).join(' ')
                end
            end
            #  Default a few things that will only be overridden on PowerHA boxes
            l_aixVgHash[l_vg]['concurrent']      = 'No'
            l_aixVgHash[l_vg]['concurrent_bool'] = false
            l_aixVgHash[l_vg]['vg_mode']         = 'Normal'
            l_aixVgHash[l_vg]['node']            = '0'
            #  Pick up all the interesting tidbits about this volume group
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/lsvg -L #{l_vg} 2>/dev/null")
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split(' ')
                if l_list.length >= 3
                    if    l_list[0] == 'VOLUME' and l_list[1] == 'GROUP:'
                        l_aixVgHash[l_vg]['vgid'] = l_list[5]
                    elsif l_list[0] == 'VG'     and l_list[1] == 'STATE:'
                        l_aixVgHash[l_vg]['state']   = l_list[2]
                        l_aixVgHash[l_vg]['pp_size'] = l_list.slice(5..6).join(' ')
                        if    l_list[6] == 'megabyte(s)'
                            l_aixVgHash[l_vg]['pp_size_mb'] = Integer(l_list[5])
                        elsif l_list[6] == 'gigabyte(s)'
                            l_aixVgHash[l_vg]['pp_size_mb'] = Integer(l_list[5]) * 1024
                        elsif l_list[6] == 'terabyte(s)'
                            l_aixVgHash[l_vg]['pp_size_mb'] = Integer(l_list[5]) * 1024 * 1024
                        end
                    elsif l_list[0] == 'VG'     and l_list[1] == 'PERMISSION:'
                        l_aixVgHash[l_vg]['permission']   = l_list[2]
                        l_aixVgHash[l_vg]['total_pps']    = l_list.slice(5..7).join(' ')
                        l_aixVgHash[l_vg]['total_pps_pp'] = Integer(l_list[5])
                        l_aixVgHash[l_vg]['total_pps_mb'] = Integer(l_list[6].split('(')[1])
                    elsif l_list[0] == 'MAX'    and l_list[1] == 'LVs:'
                        l_aixVgHash[l_vg]['max_lvs']     = Integer(l_list[2])
                        l_aixVgHash[l_vg]['free_pps']    = l_list.slice(5..7).join(' ')
                        l_aixVgHash[l_vg]['free_pps_pp'] = Integer(l_list[5])
                        l_aixVgHash[l_vg]['free_pps_mb'] = Integer(l_list[6].split('(')[1])
                    elsif l_list[0] == 'LVs:'
                        l_aixVgHash[l_vg]['num_lvs']     = Integer(l_list[1])
                        l_aixVgHash[l_vg]['used_pps']    = l_list.slice(4..6).join(' ')
                        l_aixVgHash[l_vg]['used_pps_pp'] = Integer(l_list[4])
                        l_aixVgHash[l_vg]['used_pps_mb'] = Integer(l_list[5].split('(')[1])
                    elsif l_list[0] == 'OPEN'   and l_list[1] == 'LVs:'
                        l_aixVgHash[l_vg]['open_lvs']   = Integer(l_list[2])
                        l_aixVgHash[l_vg]['quorum']     = l_list.slice(4..5).join(' ')
                        l_aixVgHash[l_vg]['quorum_int'] = Integer(l_list[4])
                    elsif l_list[0] == 'TOTAL'  and l_list[1] == 'PVs:'
                        l_aixVgHash[l_vg]['total_pvs'] = Integer(l_list[2])
                        l_aixVgHash[l_vg]['vgdas']     = Integer(l_list[5])
                    elsif l_list[0] == 'STALE'  and l_list[1] == 'PVs:'
                        l_aixVgHash[l_vg]['stale_pvs'] = Integer(l_list[2])
                        l_aixVgHash[l_vg]['stale_pps'] = Integer(l_list[5])
                    elsif l_list[0] == 'ACTIVE' and l_list[1] == 'PVs:'
                        l_aixVgHash[l_vg]['active_pvs'] = Integer(l_list[2])
                        l_aixVgHash[l_vg]['auto_on']    = l_list[5]
                    elsif l_list[0] == 'Concurrent:'
                        l_aixVgHash[l_vg]['concurrent']      = l_list[1]
                        l_aixVgHash[l_vg]['auto_concurrent'] = l_list[3]
                        if l_list[1] == 'Enhanced-Capable'
                            l_aixVgHash[l_vg]['concurrent_bool'] = true
                        else
                            l_aixVgHash[l_vg]['concurrent_bool'] = false
                        end
                    elsif l_list[0] == 'VG'     and l_list[1] == 'Mode:'
                        l_aixVgHash[l_vg]['vg_mode'] = l_list[2]
                    elsif l_list[0] == 'Node'   and l_list[1] == 'ID:'
                        l_aixVgHash[l_vg]['node']         = Integer(l_list[2])
                        l_aixVgHash[l_vg]['active_nodes'] = l_list.slice(5..-1).join(' ')
                    elsif l_list[0] == 'MAX'    and l_list[1] == 'PPs'   and l_list[2] == 'per' and l_list[3] == 'VG:'
                        l_aixVgHash[l_vg]['max_pps_per_vg'] = Integer(l_list[4])
                        if l_list.length == 8
                            l_aixVgHash[l_vg]['max_pvs'] = Integer(l_list[7])
                        end
                    elsif l_list[0] == 'MAX'    and l_list[1] == 'PPs'   and l_list[2] == 'per' and l_list[3] == 'PV:'
                        l_aixVgHash[l_vg]['max_pps_per_pv'] = Integer(l_list[4])
                        l_aixVgHash[l_vg]['max_pvs']        = Integer(l_list[7])
                    elsif l_list[0] == 'LTG'    and l_list[1] == 'size'  and l_list[2] == '(Dynamic):'
                        l_aixVgHash[l_vg]['ltg_size']  = l_list.slice(3..4).join(' ')
                        l_aixVgHash[l_vg]['auto_sync'] = l_list[7]
                    elsif l_list[0] == 'HOT'    and l_list[1] == 'SPARE:'
                        l_aixVgHash[l_vg]['hot_spare'] = l_list[2]
                        l_aixVgHash[l_vg]['bb_policy'] = l_list[5]
                    elsif l_list[0] == 'MIRROR' and l_list[1] == 'POOL'  and l_list[2] == 'STRICT:'
                        l_aixVgHash[l_vg]['mirror_pool_strict'] = l_list[3]
                    elsif l_list[0] == 'PV'     and l_list[1] == 'RESTRICTION:'
                        l_aixVgHash[l_vg]['pv_restriction'] = l_list[2]
                        l_aixVgHash[l_vg]['infinite_retry'] = l_list[5]
                    elsif l_list[0] == 'DISK'   and l_list[1] == 'BLOCK' and l_list[2] == 'SIZE:'
                        l_aixVgHash[l_vg]['disk_block_size'] = Integer(l_list[3])
                        l_aixVgHash[l_vg]['critical_vg']     = l_list[6]
                    elsif l_list[0] == 'FS'     and l_list[1] == 'SYNC'  and l_list[2] == 'OPTION:'
                        l_aixVgHash[l_vg]['fs_sync_option'] = l_list[3]
                        l_aixVgHash[l_vg]['critical_pvs']   = l_list[6]
                    end
                end
            end
        end

        #  Implicitly return the contents of the hash
        l_aixVgHash
    end
end
