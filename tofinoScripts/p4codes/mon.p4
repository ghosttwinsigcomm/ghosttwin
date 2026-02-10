#include <tna.p4>

#include "byteCount.p4"
#include "saveInfo2.p4"


typedef bit<48> mac_addr_t;
typedef bit<12> vlan_id_t;
typedef bit<16> ether_type_t;
typedef bit<32> ipv4_addr_t;


const bit<32> READ = 9999;
const bit<32> WRITE = 1111;

const bit<32> TRASH = 0000;

const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_VLAN = 16w0x8100;

const ether_type_t ETHERTYPE_MONITOR = 0x1234;

header ethernet_h {
	mac_addr_t dst_addr;
	mac_addr_t src_addr;
	bit<16> ether_type;
}

header vlan_tag_h {
	bit<3> pcp;
	bit<1> cfi;
	vlan_id_t vid;
	bit<16> ether_type;
}

header ipv4_h {
	bit<4> version;
	bit<4> ihl;
	bit<8> diffserv;
	bit<16> total_len;
	bit<16> identification;
	bit<16> flags;
	bit<8> ttl;
	bit<8> protocol;
	bit<16> hdr_checksum;
	ipv4_addr_t src_addr;
	ipv4_addr_t dst_addr;
}


header monitor_inst_h {
	 bit<32> index_flow; // index of the flow to collect the informations
	 bit<32> index_port; // index of the port to collect the informations
	 bit<9> port;		// port to forward the packet
	 bit<7> padding;
}//10 bytes

header monitor_h {
	bit<64> bytes_flow;
	bit<64> bytes_port;
	bit<48> timestamp;
	bit<9> port;
	bit<7> padding;
	bit<16> pktLen;


	bit<32> qID_port;
	bit<32> qDepth_port;
	bit<32> qTime_port;


	bit<32> qID_flow;
	bit<32> qDepth_flow;
	bit<32> qTime_flow;

}// 50 bytes



struct headers {
	pktgen_timer_header_t 	timer;
	ethernet_h				ethernet;
	monitor_inst_h 			mon_inst;
	monitor_h				monitor;
	vlan_tag_h				vlan_tag;
	ipv4_h					ipv4;
}

struct my_ingress_metadata_t {
	bit<8> ctrl;
}

struct my_egress_metadata_t {
	bit<32> qID;
	bit<32> qDepth;
	bit<32> qTime;
}


parser SwitchIngressParser(
	packet_in packet, 
	out headers hdr, 
	out my_ingress_metadata_t ig_md,
	out ingress_intrinsic_metadata_t ig_intr_md) {

	state start {
		packet.extract(ig_intr_md);
		packet.advance(PORT_METADATA_SIZE);
		
		transition parse_ethernet;
	}


	/*state start {
		packet.extract(ig_intr_md);
		packet.advance(PORT_METADATA_SIZE);
		
		pktgen_timer_header_t pktgen_pd_hdr = packet.lookahead<pktgen_timer_header_t>();
		transition select(pktgen_pd_hdr.app_id) {
			1 : parse_pktgen_timer;
			default : parse_ethernet;
		}	
	}*/


	state parse_pktgen_timer {
		//packet.extract(hdr.timer);
		ig_md.ctrl = 2;
		transition parse_ethernet;
	}

	state parse_ethernet {
		packet.extract(hdr.ethernet);
		//ig_md.ctrl = 2;
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			ETHERTYPE_VLAN:  parse_vlan;
			ETHERTYPE_MONITOR: parse_monitor;
			default: accept;
		}
	}
	
	state parse_monitor {
		packet.extract(hdr.mon_inst);
		transition accept;
	}

	state parse_vlan {
		packet.extract(hdr.vlan_tag);
		transition select(hdr.vlan_tag.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			default: accept;
		}
	}
	
	state parse_ipv4 {
		packet.extract(hdr.ipv4);
		transition accept;
	}
}


control SwitchIngress(
	inout headers hdr, 
	inout my_ingress_metadata_t ig_md,
	in ingress_intrinsic_metadata_t ig_intr_md,
	in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
	inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
	inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {
		
	action drop() {
		ig_intr_dprsr_md.drop_ctl = 0x1;
	}
	
	action send(PortId_t port) {
		ig_intr_tm_md.ucast_egress_port = port;
	}
  
	table fwd {
		key = {
			ig_md.ctrl	:	exact;
		}
		actions = {
			send;
			drop;
		}
		const default_action = drop();
		size = 1024;
	}
		
	apply {
		
		//fwd.apply();

		if(ig_md.ctrl==2 || hdr.ethernet.ether_type == ETHERTYPE_MONITOR){
			//hdr.monitor.setValid();
			//hdr.monitor.bytes = 0;
			//hdr.ethernet.ether_type = ETHERTYPE_MONITOR;
			ig_intr_tm_md.ucast_egress_port = 134;
			ig_intr_tm_md.ucast_egress_port = hdr.mon_inst.port;
			
		}else{ig_intr_tm_md.ucast_egress_port = 132;}
		
		//need to adjust the parser still
		/*if(ig_intr_md.ingress_port==196 || ig_intr_md.ingress_port==68){
			hdr.monitor.isValid();
			hdr.ethernet.ethertype = ETHERTYPE_MONITOR;
		}*/
		
	}
		
}


control SwitchIngressDeparser(
	packet_out pkt,
	inout headers hdr,
	in my_ingress_metadata_t ig_md,
	in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

	apply {
		pkt.emit(hdr);
	}
}


parser SwitchEgressParser(
	packet_in packet,
	out headers hdr,
	out my_egress_metadata_t eg_md,
	out egress_intrinsic_metadata_t eg_intr_md) {
	
	state start {
		packet.extract(eg_intr_md);
		transition parse_ethernet;
	}
	
	state parse_ethernet {
		packet.extract(hdr.ethernet);
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			ETHERTYPE_VLAN:  parse_vlan;
			ETHERTYPE_MONITOR: parse_monitor;
			default: accept;
		}
	}

	state parse_monitor {
		packet.extract(hdr.mon_inst);
		packet.extract(hdr.monitor);	// I extract to use the empty size in the packet
		transition accept;
	
	}

	state parse_vlan {
		packet.extract(hdr.vlan_tag);
		transition select(hdr.vlan_tag.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			default: accept;
		}
	}
	
	state parse_ipv4 {
		packet.extract(hdr.ipv4);
		transition accept;
	}
}


control SwitchEgress(
	inout headers hdr,
	inout my_egress_metadata_t eg_md,
	in egress_intrinsic_metadata_t eg_intr_md,
	in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
	inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
	inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
	

	Add_64_64(4096) byte_count_port;
	Add_64_64(4096) byte_count_flow;
	
	//Store_info(4096) store_info_port;
	//Store_info(4096) store_info_flow;
	

	//hashing for flows
	Hash<bit<12>>(HashAlgorithm_t.CRC32) hTableIndex;

	bit<32> flowIndex;
	bit<32> portIndex;

	bit<32> qID;
	bit<32> qDepth;
	bit<32> qTime;



	bit<64> dummy = 0;
		
	//bit<32> wri

	bit<32> d1=0;
	bit<32> d2=0;
	bit<32> d3=0;


	//tentando

	/* save the queueID that packet passes (flow saving) */
	Register<bit<32>, reg_index_t>(4096) reg_queueID_flow;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID_flow) write_id_flow = {
		void apply(inout bit<32> value, out bit<32> result) {			
			value = eg_md.qID;
		}
	};
	
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID_flow) read_id_flow = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qID; //comentar			
			result = value;
		}
	};
	
	/* save the dequeue depth that packet passes (flow saving)*/
	Register<bit<32>, reg_index_t>(4096) reg_queueDepth_flow;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth_flow) write_depth_flow = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = eg_md.qDepth;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth_flow) read_depth_flow = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qDepth; //comentar		
			result = value;
		}
	};
	
	/* save the queue time that packet passes (flow saving)*/
	Register<bit<32>, reg_index_t>(4096) reg_Time_flow;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time_flow) write_time_flow = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = eg_md.qTime;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time_flow) read_time_flow = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qTime;//comentar		
			result = value;
		}
	};
	
	//----------------------------------------------------------------------------------------

	/* save the queueID that packet passes (port saving) */
	Register<bit<32>, reg_index_t>(4096) reg_queueID_port;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID_port) write_id_port = {
		void apply(inout bit<32> value, out bit<32> result) {			
			value = eg_md.qID;
		}
	};
	
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID_port) read_id_port = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qID;//comentar			
			result = value;
		}
	};
	
	/* save the dequeue depth that packet passes (port saving)*/
	Register<bit<32>, reg_index_t>(4096) reg_queueDepth_port;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth_port) write_depth_port = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = eg_md.qDepth;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth_port) read_depth_port = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qDepth; //cmentar		
			result = value;
		}
	};
	
	/* save the queue time that packet passes (port saving)*/
	Register<bit<32>, reg_index_t>(4096) reg_Time_port;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time_port) write_time_port = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = eg_md.qTime;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time_port) read_time_port = {
		void apply(inout bit<32> value, out bit<32> result) {
			value = eg_md.qTime; // comentar		
			result = value;
		}
	};

	//fim

	apply {
	
	
		bit<64> l_1 = 0;
		l_1 = (bit<64>)(eg_intr_md.pkt_length);
		//take the indexes
			

			eg_md.qID = (bit<32>)(eg_intr_md.egress_qid);
			eg_md.qDepth = (bit<32>)(eg_intr_md.deq_qdepth);
			eg_md.qTime = (bit<32>)(eg_intr_md.enq_tstamp);
		
		flowIndex = (bit<32>)(hTableIndex.get({hdr.ethernet.src_addr, hdr.ethernet.dst_addr})); 
		portIndex = (bit<32>)(eg_intr_md.egress_port);

		//collect the information	
		if(hdr.monitor.isValid()){
			hdr.monitor.timestamp = eg_intr_md_from_prsr.global_tstamp;
			hdr.monitor.port = eg_intr_md.egress_port;
			hdr.monitor.pktLen = eg_intr_md.pkt_length;
			
			//byte_count_port.apply(hdr.monitor.bytes, l_1, (bit<32>)eg_intr_md.egress_port);
			byte_count_port.apply(hdr.monitor.bytes_port, l_1, hdr.mon_inst.index_port);
			
			byte_count_flow.apply(hdr.monitor.bytes_flow, l_1, hdr.mon_inst.index_flow);

			//nova tentativa
			hdr.monitor.qID_flow = read_id_flow.execute(hdr.mon_inst.index_flow);
			hdr.monitor.qDepth_flow = read_depth_flow.execute(hdr.mon_inst.index_flow);
			hdr.monitor.qTime_flow = read_time_flow.execute(hdr.mon_inst.index_flow);
		
			hdr.monitor.qID_port = read_id_port.execute(hdr.mon_inst.index_port);
			hdr.monitor.qDepth_port =read_depth_port.execute(hdr.mon_inst.index_port);
			hdr.monitor.qTime_port = read_time_port.execute(hdr.mon_inst.index_port);
			//fim da nova tentativa

			/*nao funcionou
			//store_info_port.apply(READ, hdr.mon_inst.index_port, qID, qDepth, qTime);

			//should be read
			store_info_port.apply(WRITE, hdr.mon_inst.index_port, hdr.monitor.qID_port, hdr.monitor.qDepth_port, hdr.monitor.qTime_port);
			//store_info_port.apply(READ, hdr.mon_inst.index_port, d1, d2, d3, hdr.monitor.qID_port, hdr.monitor.qDepth_port, hdr.monitor.qTime_port);

			//trying
			store_info_flow.apply(WRITE, hdr.mon_inst.index_flow, hdr.monitor.qID_flow, hdr.monitor.qDepth_flow, hdr.monitor.qTime_flow);
			*/
		}
		//calculate the information
		else{
		
			
			//calculate bytes
			//byte_count_port.apply(hdr.monitor.bytes, l_1, (bit<32>)eg_intr_md.egress_port);
			byte_count_port.apply(dummy, l_1, portIndex);
			byte_count_flow.apply(dummy, l_1, flowIndex);			

			//save other informations (tava aqui)
			/*
			eg_md.qID = (bit<32>)(eg_intr_md.egress_qid);
			eg_md.qDepth = (bit<32>)(eg_intr_md.deq_qdepth);
			eg_md.qTime = (bit<32>)(eg_intr_md.enq_tstamp);
			*/
			
			//nova tentativa
			write_id_flow.execute(flowIndex);
			write_depth_flow.execute(flowIndex);
			write_time_flow.execute(flowIndex);
	
			write_time_port.execute(portIndex);
			write_depth_port.execute(portIndex);
			write_time_port.execute(portIndex);
	
			//fim da nova tentativa

			//store_info_port.apply(WRITE, portIndex, qID, qDepth, qTime); //last
			//store_info_port.apply(WRITE, portIndex, qID, qDepth, qTime, d1, d2, d3);


			//trying
			//store_info_port.apply(WRITE, flowIndex, qID, qDepth, qTime);
		
		
		}




	}
}

control SwitchEgressDeparser(
	packet_out pkt,
	inout headers hdr,
	in my_egress_metadata_t eg_md,
	in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
		
	apply {
		pkt.emit(hdr);
	}
}

Pipeline(SwitchIngressParser(),
		SwitchIngress(),
		SwitchIngressDeparser(),
		SwitchEgressParser(),
		SwitchEgress(),
		SwitchEgressDeparser()) pipe;

Switch(pipe) main;
