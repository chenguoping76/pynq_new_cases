/*
 *  vitis standard (baremetel) project should include the IP's driver directory of the hls project
 *  for example the directory is <project_root>10tpg\hls_proj\tpg_stream\solution1\impl\ip\drivers\tpg_v2_0\src
 */

#include "Xtpg.h"
#include "xil_cache.h"
#include "xil_printf.h"

#include "xparameters.h"

#define TPG_ID XPAR_TPG_0_DEVICE_ID

#define WIDTH 640
//#define HEIGHT 480
//#define IM_SIZE WIDTH*HEIGHT

unsigned int image[WIDTH];
XTpg tpgIns;
int main()
{
	int Status;
	Status = XTpg_Initialize(&tpgIns, TPG_ID);
	if(Status != XST_SUCCESS)
		xil_printf("Error initialize HLS Tpg IP.\r\n");

	for(int j = 0 ; j < WIDTH ; j++)	image[j] = 640 - j;

//    void XTpg_Set_image_r(XTpg *InstancePtr, u64 Data);
    XTpg_Set_image_r(&tpgIns, (u64)image);
//    void XTpg_Set_lines(XTpg *InstancePtr, u32 Data);
    XTpg_Set_lines(&tpgIns, (u32)HEIGHT);
//	Xil_DCacheFlushRange((INTPTR)image, sizeof(image));

    Xil_DCacheFlushRange((INTPTR)image, sizeof(image));

	XTpg_Start(&tpgIns);
	while(!(XTpg_IsDone(&tpgIns)));

	while(1){
		;
	}
	return 0;
}
