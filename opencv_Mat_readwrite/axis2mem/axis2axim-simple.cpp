#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_stream.h"

#define DATA_WIDTH 32

typedef ap_axiu<DATA_WIDTH,1,1,1> trans_pkt;


void axis2mem(
	hls::stream<trans_pkt>& axis_input, 				   // AXI-Stream 输入
    unsigned int* axi_mem,                                 // AXI4-Master 内存指针
	unsigned int total_size                                // 传输总数据量（单位：字）
) {
    #pragma HLS INTERFACE axis port=axis_input
    #pragma HLS INTERFACE m_axi depth=640 port=axi_mem
    #pragma HLS INTERFACE s_axilite port=total_size bundle=control
    #pragma HLS INTERFACE s_axilite port=return bundle=control

	loop: for(unsigned int i = 0; i < total_size; i++) {
		#pragma HLS PIPELINE II=1
		trans_pkt in_val = axis_input.read();
		axi_mem[i] = in_val.data;
	}
        
}
