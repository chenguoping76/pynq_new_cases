/*
*   for windows system vitis library locate in C:\Users\<用户名（全英文无空格）>\.Xilinx\Vitis\2023.1\vitis_libraries\vision\L1\include
*   vitis_hls CFLAGS -IC:\Users\<用户名>\.Xilinx\Vitis\2023.1\vitis_libraries\vision\L1\include -D__SDSVHLS__ -std=c++0x
*/

#include "hls_stream.h"
#include "common/xf_common.hpp"
#include "common/xf_utility.hpp"
#include "common/xf_infra.hpp"
#include <ap_fixed.h>
#include <string.h>
#include <stdio.h>
#define MAX_WIDTH  640
#define MAX_HEIGHT 480
#define WIDTH 32				// modify WIDTH 16 to 32, 与unsigned int数据宽度一致
typedef hls::stream<ap_axiu<WIDTH,1,1,1> > axis;
typedef ap_axiu<WIDTH,1,1,1> VIDEO_COMP;

void tpg(axis& OUTPUT_STREAM, int lines, unsigned int* image ){
#pragma HLS INTERFACE m_axi depth=640 port=image offset=slave
#pragma HLS INTERFACE axis register both port=OUTPUT_STREAM
#pragma HLS INTERFACE s_axilite port=return
#pragma HLS INTERFACE s_axilite port=lines
#define line_size 640
#define numb_lines 512
VIDEO_COMP tpg_gen;
int i = 0;
int y = 0;
int x = 0;
int frm_lines =0;
int frame[line_size];
outer_loop:for (y =0; y<lines; y++){
    memcpy(frame,image,line_size*sizeof(int));
    tpg_label0:for (x =0; x <  line_size; x++) {
        if (y == 0 && x == 0 ){
            tpg_gen.user = 1;
            tpg_gen.data = frame[x];
        }
        else{
            if (x == 639 ){
                tpg_gen.last = 1;
                tpg_gen.data = frame[x];
            }
            else{
                tpg_gen.last = 0;
                tpg_gen.user = 0;
                tpg_gen.data = frame[x];
            }
        }
        OUTPUT_STREAM.write(tpg_gen);
    }
  }
}
