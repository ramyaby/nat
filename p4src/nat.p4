/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

             action drop() {
                mark_to_drop(standard_metadata);
          }


             action set_nhop(macAddr_t dstAddr, egressSpec_t port) {
                 hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
                 hdr.ethernet.dstAddr = dstAddr;
       		 standard_metadata.egress_spec = port;
      		  hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
         }

         action src_map(bit<32> addr){
      			  hdr.ipv4.srcAddr=addr;
   	    }

   	  table src_nat{
             key = {
                hdr.ipv4.srcAddr:exact;
	         }
         actions = {
          src_map;
        }
     }

     action dst_map(bit<32> addr){
         hdr.ipv4.dstAddr=addr;
      }

     table dst_nat {
      key = {
       hdr.ipv4.dstAddr:exact;
       }

       actions = {
            dst_map;
        }
     }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            set_nhop;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

     apply {

          if( ! src_nat.apply().hit){
              dst_nat.apply();
            }
            ipv4_lpm.apply();

    }

}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {

    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
              hdr.ipv4.hdrChecksum,
              HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
