#
#  FACT(S):     aix_lvs
#
#  PURPOSE:     This custom fact returns a hash of information about the logical
#		volumes on the local machine that are part of varied-on volume
#		groups.  [Important caveat!]
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
Facter.add(:aix_lvs) do
    #  This only applies to the AIX operating system
    confine :osfamily => 'AIX'

    #  
    setcode do
        #  Define the hash and array we'll need
        l_aixLvHash      = {}
        #
        l_aixVgVariedOn  = []

        #  Grab the list of volume groups that are varied on (one way or another)
        l_lines = Facter::Util::Resolution.exec('/usr/sbin/lsvg -L -o 2>/dev/null')
        l_lines && l_lines.split("\n").each do |l_oneLine|
            l_aixVgVariedOn.push(l_oneLine.strip())
        end

        #  Loop over the varied-on VGs, list out their LVs to put keys in the hash
        l_aixVgVariedOn.each do |l_vg|
            l_state = 0			#  Trivial DFA/FSM to skipp headings
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/lsvg -L -l #{l_vg}  2>/dev/null")
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split(' ')
                if l_state == 0 
                    if l_list.length > 0 and l_list[0] == 'LV'
                        l_state = 1
                    end
                elsif l_state == 1
                    l_aixLvHash['/dev/' + l_list[0]] = {}
                end
            end
        end

        #  Loop over the keys in the hash and try to get good data about each LV
        l_aixLvHash.keys.each do |l_lv|
            #  Since we're using LV names/keys that match other things, compute the short name
            l_lvShortName = l_lv.split('/')[2]
            #  Set a few things that we'll override in PowerHA land
            l_aixLvHash[l_lv]['preferred_read'] = 'N/A'
            l_aixLvHash[l_lv]['device_subtype'] = 'N/A'
            l_aixLvHash[l_lv]['copy_1_pool']    = 'N/A'
            l_aixLvHash[l_lv]['copy_2_pool']    = 'N/A'
            l_aixLvHash[l_lv]['copy_3_pool']    = 'N/A'
            #  Loop over the output of 'lslv -L {name}'
            l_lines = Facter::Util::Resolution.exec("/usr/sbin/lslv -L #{l_lvShortName}  2>/dev/null")
            l_lines && l_lines.split("\n").each do |l_oneLine|
                l_list = l_oneLine.split()
                if l_list.length >= 3
                    if    l_list[0] == 'LOGICAL' and l_list[1] == 'VOLUME:'
                        l_aixLvHash[l_lv]['vg'] = l_list[5]
                    elsif l_list[0] == 'LV' and l_list[1] == 'IDENTIFIER:'
                        l_aixLvHash[l_lv]['lvid']       = l_list[2]
                        l_aixLvHash[l_lv]['permission'] = l_list[4]
                    elsif l_list[0] == 'VG' and l_list[1] == 'STATE:'
                        l_aixLvHash[l_lv]['vg_state']   = l_list[2]
                        l_aixLvHash[l_lv]['lv_state']   = l_list[5]
                    elsif l_list[0] == 'TYPE:' 
                        l_aixLvHash[l_lv]['type']         = l_list[1]
                        l_aixLvHash[l_lv]['write_verify'] = l_list[4]
                    elsif l_list[0] == 'MAX' and l_list[1] == 'LPs:'
                        l_aixLvHash[l_lv]['max_lps']      = l_list[2]
                        l_aixLvHash[l_lv]['max_lps_int']  = Integer(l_list[2])
                        l_aixLvHash[l_lv]['pp_size']      = l_list.slice(5..-1).join(' ')
                        l_aixLvHash[l_lv]['pp_size_mb']   = Integer(l_list[5])
                    elsif l_list[0] == 'COPIES:' 
                        l_aixLvHash[l_lv]['copies']       = l_list[1]
                        l_aixLvHash[l_lv]['copies_int']   = Integer(l_list[1])
                        l_aixLvHash[l_lv]['sched_policy'] = l_list[4]
                    elsif l_list[0] == 'LPs:' 
                        l_aixLvHash[l_lv]['lps']       = l_list[1]
                        l_aixLvHash[l_lv]['lps_int']   = Integer(l_list[1])
                        l_aixLvHash[l_lv]['pps']       = l_list[3]
                        l_aixLvHash[l_lv]['pps_int']   = Integer(l_list[3])
                    elsif l_list[0] == 'STALE' and l_list[1] == 'PPs:'
                        l_aixLvHash[l_lv]['stale_pps']     = l_list[2]
                        l_aixLvHash[l_lv]['stale_pps_int'] = Integer(l_list[2])
                        l_aixLvHash[l_lv]['bb_policy']     = l_list[5]
                    elsif l_list[0] == 'INTER-POLICY:' 
                        l_aixLvHash[l_lv]['inter_policy'] = l_list[1]
                        l_aixLvHash[l_lv]['relocatable']  = l_list[3]
                    elsif l_list[0] == 'INTRA-POLICY:' 
                        l_aixLvHash[l_lv]['intra_policy']    = l_list[1]
                        l_aixLvHash[l_lv]['upper_bound']     = l_list[4]
                        l_aixLvHash[l_lv]['upper_bound_int'] = Integer(l_list[4])
                    elsif l_list[0] == 'MOUNT' and l_list[1] == 'POINT:'
                        l_aixLvHash[l_lv]['mount_point'] = l_list[2]
                        l_aixLvHash[l_lv]['label']       = l_list[4]
                    elsif l_list[0] == 'DEVICE' and l_list[1] == 'UID:'
                        l_aixLvHash[l_lv]['uid'] = Integer(l_list[2])
                        l_aixLvHash[l_lv]['gid'] = Integer(l_list[5])
                    elsif l_list[0] == 'DEVICE' and l_list[1] == 'PERMISSIONS:'
                        l_aixLvHash[l_lv]['dev_permissions'] = l_list[2]
                    elsif l_list[0] == 'MIRROR' and l_list[1] == 'WRITE' and l_list[2] == 'CONSISTENCY:'
                        l_aixLvHash[l_lv]['mirror_w_consistency'] = l_list[3]
                    elsif l_list[0] == 'EACH' and l_list[1] == 'LP' and l_list[2] == 'COPY'
                        l_aixLvHash[l_lv]['separate_lps'] = l_list[8]
                    elsif l_list[0] == 'Serialize' and l_list[1] == 'IO'
                        l_aixLvHash[l_lv]['serialize_io'] = l_list[3]
                    elsif l_list[0] == 'INFINITE' and l_list[1] == 'RETRY:'
                        l_aixLvHash[l_lv]['infinite_retry'] = l_list[2]
                        if l_list.length > 3
                            l_aixLvHash[l_lv]['preferred_read'] = l_list[5]
                        end
                    elsif l_list[0] == 'DEVICESUBTYPE:'
                        l_aixLvHash[l_lv]['device_subtype'] = l_list[1]
                    elsif l_list[0] == 'COPY' and l_list[1] == '1' and l_list[2] == 'MIRROR'
                        l_aixLvHash[l_lv]['copy_1_pool']    = l_list[4]
                    elsif l_list[0] == 'COPY' and l_list[1] == '2' and l_list[2] == 'MIRROR'
                        l_aixLvHash[l_lv]['copy_2_pool']    = l_list[4]
                    elsif l_list[0] == 'COPY' and l_list[1] == '3' and l_list[2] == 'MIRROR'
                        l_aixLvHash[l_lv]['copy_3_pool']    = l_list[4]
                    end
                end
            end
        end

        #  Implicitly return the contents of the hash
        l_aixLvHash
    end
end
