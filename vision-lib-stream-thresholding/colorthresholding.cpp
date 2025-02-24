// Copyright (C) 2021 Xilinx, Inc
//
// SPDX-License-Identifier: BSD-3-Clause

#include "hls_stream.h"
#include "common/xf_common.hpp"
#include "common/xf_infra.hpp"
#include "imgproc/xf_colorthresholding.hpp"

#define DATA_WIDTH 24
#define NPIX XF_NPPC1

/*  set the height and width  */
#define WIDTH 1920
#define HEIGHT 1080
#define INTYPE XF_8UC3
#define OUTTYPE XF_8UC3		// change XF_8UC1 to XF_8UC3 by guoping 2025.2.24
#define MAXCOLORS 3		// 3 type colors, for example: pink, yellow-green, purple

typedef ap_axiu<DATA_WIDTH,1,1,1> interface_t;
typedef hls::stream<interface_t> stream_t;



template <int W, int TYPE, int ROWS, int COLS, int NPPC>
void axis2xfMat (hls::stream<ap_axiu<W, 1, 1, 1> >& AXI_video_strm, xf::cv::Mat<TYPE, ROWS, COLS, NPPC>& img) {
    ap_axiu<W, 1, 1, 1> axi;

    const int m_pix_width = XF_PIXELWIDTH(TYPE, NPPC) * XF_NPIXPERCYCLE(NPPC);

    int rows = img.rows;
    int cols = img.cols >> XF_BITSHIFT(NPPC);

    assert(img.rows <= ROWS);
    assert(img.cols <= COLS);

loop_row_axi2mat:
    for (int i = 0; i < rows; i++) {
    loop_col_zxi2mat:
        for (int j = 0; j < cols; j++) {
#pragma HLS loop_flatten off
#pragma HLS pipeline II=1

            AXI_video_strm.read(axi);
            img.write(i*rows + j, axi.data(m_pix_width - 1, 0));
        }
    }
}

template <int W, int TYPE, int ROWS, int COLS, int NPPC>
void xfMat2axis(xf::cv::Mat<TYPE, ROWS, COLS, NPPC>& img, hls::stream<ap_axiu<W, 1, 1, 1> >& dst) {
    ap_axiu<W, 1, 1, 1> axi;

    int rows = img.rows;
    int cols = img.cols >> XF_BITSHIFT(NPPC);

    assert(img.rows <= ROWS);
    assert(img.cols <= COLS);

    const int m_pix_width = XF_PIXELWIDTH(TYPE, NPPC) * XF_NPIXPERCYCLE(NPPC);

loop_row_mat2axi:
    for (int i = 0; i < rows; i++) {
    loop_col_mat2axi:
        for (int j = 0; j < cols; j++) {
#pragma HLS loop_flatten off
#pragma HLS pipeline II = 1

            /*Assert last only in the last pixel*/
            if ((j == cols-1) && (i == rows-1)) {
                axi.last = 1;
            } else {
                axi.last = 0;
            }

            axi.data = 0;
            axi.data(m_pix_width - 1, 0) = img.read(i*rows + j);
            axi.keep = -1;
            dst.write(axi);
        }
    }
}


//https://xilinx.github.io/Vitis_Libraries/vision/2020.2/api-reference.html#color-thresholding
void colorthresholding_accel(stream_t& stream_in, 
                             stream_t& stream_out, 
                             unsigned char lower_threshold[MAXCOLORS*3],   // each colors value in 3 channels(r,g,b)
                             unsigned char upper_threshold[MAXCOLORS*3],
                             unsigned int rows,
                             unsigned int cols)
{
#pragma HLS INTERFACE axis register both port=stream_in
#pragma HLS INTERFACE axis register both port=stream_out

#pragma HLS INTERFACE s_axilite port=lower_threshold
#pragma HLS INTERFACE s_axilite port=upper_threshold
#pragma HLS INTERFACE s_axilite port=rows
#pragma HLS INTERFACE s_axilite port=cols
#pragma HLS INTERFACE s_axilite port=return

    xf::cv::Mat<INTYPE, HEIGHT, WIDTH, NPIX> img_in(rows, cols);
    xf::cv::Mat<OUTTYPE, HEIGHT, WIDTH, NPIX> img_out(rows, cols);

#pragma HLS DATAFLOW

    // Convert stream in to xf::cv::Mat
    //xf::cv::AXIvideo2xfMat<DATA_WIDTH, INTYPE, HEIGHT, WIDTH, NPIX>(stream_in, img_in);
    axis2xfMat<DATA_WIDTH, INTYPE, HEIGHT, WIDTH, NPIX>(stream_in, img_in);
    // Run xfOpenCV kernel:
    xf::cv::colorthresholding<INTYPE, OUTTYPE, MAXCOLORS, HEIGHT, WIDTH, NPIX>(img_in, img_out, lower_threshold, upper_threshold);

    // Convert xf::cv::Mat to stream
    //xf::cv::xfMat2AXIvideo<DATA_WIDTH, OUTTYPE, HEIGHT, WIDTH, NPIX>(img_out, stream_out);
    xfMat2axis<DATA_WIDTH, OUTTYPE, HEIGHT, WIDTH, NPIX>(img_out, stream_out);
}
