/*
 *  vitis standard (baremetel) project should include the IP's driver directory of the hls project
 *  for example the directory is <project_root>10tpg\hls_proj\tpg_stream\solution1\impl\ip\drivers\tpg_v2_0\src
 */


#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"

#include "Xtpg.h"
#include "xaxis2mem.h"

#define TPG_ID 			XPAR_TPG_0_DEVICE_ID
#define XAXIS2MEM_ID	XPAR_AXIS2MEM_0_DEVICE_ID
#define WIDTH 640
#define HEIGHT 480
//#define IM_SIZE WIDTH*HEIGHT

unsigned int image[WIDTH];
unsigned int receive[WIDTH*HEIGHT];

XTpg 		tpgIns;
XAxis2mem	axis2memIns;
int main()
{
	int Status;
	Status = XTpg_Initialize(&tpgIns, TPG_ID);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initialize HLS Tpg IP.\r\n");
		return -1;
	}
	
	Status = XAxis2mem_Initialize(&axis2memIns, XAXIS2MEM_ID);
	if(Status != XST_SUCCESS) {
		xil_printf("Error initialize HLS AXIS2MEM IP.\r\n");
		return -2;
	}
	
	for(int j = 0 ; j < WIDTH ; j++)	image[j] = 640 - j;
	for(unsigned int j = 0 ; j < WIDTH*HEIGHT ; j++)	receive[j] = 0;
//    void XTpg_Set_image_r(XTpg *InstancePtr, u64 Data);
    XTpg_Set_image_r(&tpgIns, (u64)image);
//    void XTpg_Set_lines(XTpg *InstancePtr, u32 Data);
    XTpg_Set_lines(&tpgIns, (u32)HEIGHT);
//	Xil_DCacheFlushRange((INTPTR)image, sizeof(image));

    Xil_DCacheFlushRange((INTPTR)image, sizeof(image));
	
	XAxis2mem_Set_axi_mem(&axis2memIns, (u64)receive);
	XAxis2mem_Set_total_size(&axis2memIns, (u32)WIDTH*HEIGHT);

	XAxis2mem_Start(&axis2memIns);
	XTpg_Start(&tpgIns);
	
	while(!(XTpg_IsDone(&tpgIns)));
	while(!(XAxis2mem_IsDone(&axis2memIns)));

	while(1){
		;
	}
	return 0;
}
