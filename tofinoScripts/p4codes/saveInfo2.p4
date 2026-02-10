
const bit<32> READ_ONLY = 9999;

/*control Store_info(
	in bit<32> op,
	in  reg_index_t idx,
	in bit<32> qID,
	in bit<32> qDepth,
	in bit<32> qTime,
	out bit<32> qID_out,
	out bit<32> qDepth_out,
	out bit<32> qTime_out)
	(bit<32> reg_size)
{*/

control Store_info(
	in bit<32> op,
	in  reg_index_t idx,
	inout bit<32> qID,
	inout bit<32> qDepth,
	inout bit<32> qTime)
	(bit<32> reg_size)
{




	/* save the queueID that packet passes */
	Register<bit<32>, reg_index_t>(reg_size) reg_queueID;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID) set_id = {
		void apply(inout bit<32> value, out bit<32> result) {			
				value = qID;
			result = value;
		}
	};
	
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueID) get_id = {
		void apply(inout bit<32> value, out bit<32> result) {			
			result = value;
		}
	};

	/* save the dequeue depth that packet passes */
	Register<bit<32>, reg_index_t>(reg_size) reg_queueDepth;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth) set_depth = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = qDepth;
			result = value;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_queueDepth) get_depth = {
		void apply(inout bit<32> value, out bit<32> result) {		
			result = value;
		}
	};

	/* save the queue time that packet passes */
	Register<bit<32>, reg_index_t>(reg_size) reg_Time;
	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time) set_time = {
		void apply(inout bit<32> value, out bit<32> result) {		
			value = qTime;
			result = value;
		}
	};

	RegisterAction<bit<32>, reg_index_t, bit<32>>(reg_Time) get_time = {
		void apply(inout bit<32> value, out bit<32> result) {		
			result = value;
		}
	};


	action add_id(){
		//qID_out = get_id.execute(idx);
		qID = set_id.execute(idx);	
	}


	action add_depth(){
		//qDepth_out = get_depth.execute(idx);	
		qDepth = set_depth.execute(idx);	
	}
	
	action add_time(){
		//qTime_out = get_time.execute(idx);
		qTime = set_time.execute(idx);
	}

	action got_id(){
		//qID_out = get_id.execute(idx);
		qID = get_id.execute(idx);	
	}


	action got_depth(){
		//qDepth_out = get_depth.execute(idx);	
		qDepth = get_depth.execute(idx);	
	}
	
	action got_time(){
		//qTime_out = get_time.execute(idx);
		qTime = get_time.execute(idx);
	}



	apply{


		if(op!=READ_ONLY){
		qID = set_id.execute(idx);	

		//qDepth_out = get_depth.execute(idx);	
		qDepth = set_depth.execute(idx);	

		//qTime_out = get_time.execute(idx);
		qTime = set_time.execute(idx);
		}else{
		//qID_out = get_id.execute(idx);
		qID = get_id.execute(idx);	

		//qDepth_out = get_depth.execute(idx);	
		qDepth = get_depth.execute(idx);	

		qTime = get_time.execute(idx);
	}


/*
		if(op==READ_ONLY){
			got_id();
		
			got_depth();
		
			got_time();

		
		}else{
			add_id();
		
			add_depth();
		
			add_time();
		
		
		}*/
		
		
	
	
	}






}
